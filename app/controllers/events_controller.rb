class EventsController < ApplicationController

  # XXX Select auth based on token type, see logs_controller ?
  before_filter :json_authenticate, :except=>[:create]
  before_filter :json_lock_auth, :only=>[:create]

  # not needed, default is to push json 1-level hash to params:
  #wrap_parameters :json format: [:json, :xml]
  respond_to :json

  def index
    if (params[:lock_id])
      # XXX not fully implemented, need query per below!
      lock = Lock.where(:id => params[:lock_id].to_i).first
      return render_error_modelname(404, :MISSING_RECORD, Lock) if lock == nil
      return render_error(403, :ADMIN_ACCESS) if ! lock.account_is_admin?(@current_account)

      events = Event.where(:lock_id => params[:lock_id].to_i)
    else
      # Apparently AR is smart enough to chain the nested associations for us.
      # Don't need the lock/locks_user record, just need to select on it, so .join
      # Yes, table plurality is inconsistent between join and where/arel; join is singular for belongs_to.
      locks_user_arel = LocksUser.arel_table
      lock_arel = Lock.arel_table
      event_arel = Event.arel_table
      # If authed user is lock admin or owner:
      # Includes = left outer join, which is required to returns a
      # record if EITHER join table has a matching key.
      # Default SQL operator precedence OK here, see .grouping to do otherwise
      # FOR UPDATE conflicts with DISTINCT, not needed, perhaps
      # .readonly eliminates some overhead and should always be used
      # for query?
      # references is a new requirement for includes.
      # Allow events (e.g. battery/proximity) before commissioning is complete, though
      # no specific requirement.
      events = Event.includes(:lock)
                    .includes(:lock => :locks_users)
                    .includes(:key => {:user => :account})
                    .includes(:user => :account)
                    .includes(:picture)
        .where((
                (locks_user_arel[:user_id].eq(@current_account.user.id)
                 .and(locks_user_arel[:admin].eq(true))
                )
                .or(lock_arel[:user_id].eq(@current_account.user.id))
               )
               .and(lock_arel[:decommission_date].eq(nil)))
                    .order("events.event_time DESC")
                    .readonly(true)
                    .references(:locks_users)
                    .distinct
                    .limit(30)
        # XXX performance: For some yet known reason, the .limit clause causes two
        # queries, versus a single query.
        # XXX Sep of concerns: try .merge(Lock.not_decommissioned)
    end

    json = []
    events.each do |event|
      json << event_payload(event)
    end

    render :json => json
  end

  #GET /events/id
  def show
    #it is implied that params[:id] is present
    ev = Event.find_by_id(params[:id]) #find_by_id so exception is not raised
    return render_error_modelname(404, :MISSING_RECORD, Event) unless ev
    render :json => event_payload(ev)
  end

  # Returns one event hash to add to reply payload.
  def event_payload(event)
    # Lookup the picture when we don't have it's id, then write it out.
    # We want the latest asyncronously uploaded picture before/at
    # the event, within reason.
    # OVERLAPS isn't in MySQL, but apparently is more efficient.
    # XXX Potential race condition if we get here while a second picture
    # is uploading and cache the first picture's id.
    # Discussed in the LP ticket.
    # Includes/preload/joins etc. can't load event.picture association
    # unless the id is present, apparently.
    # So do a separate query as needed.
    # There is possibly an arel way, seems more obtuse, or perhaps
    # we could process the raw SQL results ourselves?
    #  .joins("LEFT OUTER JOIN pictures ON pictures.id = events.picture_id OR ((pictures.lock_id = events.lock_id) AND ((pictures.taken_at, INTERVAL '" + ApplicationController.MAX_PICTURE_ASYNC.to_s + " seconds') OVERLAPS (events.event_time, events.event_time))")
    if event.gets_photo?
      if !event.picture
        ev_time = event.event_time.strftime("%F %T.%3N")
        # Might be faster to use ? ev_time substitution in SQL?
        pictures = Picture.where(lock_id: event.lock_id)
                          .where("(taken_at, INTERVAL ?) OVERLAPS (TIMESTAMP ?, INTERVAL ?)",
                                 ApplicationController.MAX_PICTURE_ASYNC.to_s + " seconds",
                                 ev_time,
                                 ApplicationController.MAX_PICTURE_SKEW.to_s + " seconds")
                          .order("pictures.taken_at DESC")
                          .limit(1)
        if (pictures.first)
          event.picture = pictures.first
          # Performance: save the picture_id.  Stupid RA, stop helping me!
          # XXX recover from race condition: don't save unless times are really close.
          # At the cost of performance in the case of upload times>MAX_PICTURE_ASYNC
          # suppressing pictures on intervening events.
          event.send(:instance_variable_set, :@readonly, false)
          if !event.save
            check_save_failure(event)
            return
          end
        end
      end
    end
    event_output = get_payload_hash(event, nil, nil, true)
      # Tell the app if it should keep polling for picture.
    if event.gets_photo? && !event.picture
      event_output[:picture_pending] = (Time.now < 
                                        event.event_time + ApplicationController.MAX_PICTURE_ASYNC_TIME).to_s
    end
    event_output[:picture_url] = event.picture.try(:data).try(:expiring_url, GojiServer.config.s3_url_expire)
    event_output[:lock_name] = event.lock.name
    # XXX only send this when different than user_display_name (share/revoke/AccessChanged) or there is no user_display_name (expired)
    event_output[:key_user_id] = event.key.user_id if event.key
    event_output[:key_user_display_name] = event.key.user.display_name if event.key
    event_output[:user_display_name] = event.user.display_name if event.user
    event_output[:admin_display_name] = event.admin.display_name if event.admin

    return event_output
  end

  def create
    # This is currently only ever called from the lock. We'll determine the lock
    # based on the following. params[:authtoken].present? from app; otherwise: from lock
    return if params_missing([ :lock_id, :lock_serial ], params, true)

    lock = Lock.get_active_else_not(params)
    return render_error_modelname(404, :MISSING_RECORD, Lock) if lock.nil?

    if is_not_allowed_event_from_lock?(params)
       return render_error(422, :INVALID_PARAM, {value: params[:event_type], attribute: "event_type"})
    end

    # Update state of the lock
    # If/when we process past events, this will need to be modified so
    # old events don't incorrectly update this information
    # Assumes only lock calls this endpoint.
    lock.bolt_state = params[:bolt_state] if params[:bolt_state]
    lock.update_with_wifi(LockCommState::LOCK_COMM_UP, request.uuid)

    @event = Event.new(:key_id       => params[:key_id],
                       :user_id      => params[:user_id],
                       :admin_user_id=> params[:admin_user_id],
                       :lock         => lock,
                       :event_time   => params[:event_time],
                       :event_type   => params[:event_type],
                       :string_value => params[:string_value],
                       :int_value    => params[:int_value],
                       :bolt_state   => params[:bolt_state],
                       :uuid         => request.uuid,)
    return render_validation_error(@event) if ! @event.valid?

    if params[:picture]
      # If the picture upload fails, it will log an error and continue
      # to save the event.
      begin
        @event.picture_id = process_picture(params[:picture], lock).id
      rescue
        logger.error "===== Warning ====="
        logger.error "The picture could not be saved"
        logger.error "Error: #{$!}"
        logger.error "==================="
      end
    end
    if @event.save
      render_success
    else
      render_error_modelname(500, :DATABASE_RECORD, model.class)
    end
  end

  def process_picture(picture, lock)
    # TODO, do we need some sort of transacation handling around this?
    if picture
      raise "The picture data is missing." if picture[:data].nil?

      logger.debug "Byte count from picture[:data]: #{picture[:data].bytesize}\n"
      logger.debug "First 40 bytes from picture[:data]: #{picture[:data][0..40]}\n"
      logger.debug "Mime Content Type:         #{picture[:content_type]}\n"
      logger.debug "Filename :                 #{picture[:original_filename]}\n"

      pic = Picture.create!(data: StringIO.new(Base64.decode64(picture[:data])),
                            lock: lock,
                            # Temporary...
                            taken_at: DateTime.now,
                            uuid: request.uuid,
                            data_content_type: picture[:content_type],
                            data_file_name:    picture[:original_filename])
    end
  end

  def is_not_allowed_event_from_lock?(params)
    event_type = params[:event_type]
    if ( event_type != EventType::LOCK &&
         event_type != EventType::UNLOCK &&
         event_type != EventType::LOCK_COM &&
         event_type != EventType::BATTERY &&
         event_type != EventType::ERROR_NOTIFY_SYSADMIN &&
         event_type != EventType::ERROR_NOTIFY_OWNER_ADMIN &&
         event_type != EventType::PROXIMITY)
         return true
    end
    return false
  end

end
