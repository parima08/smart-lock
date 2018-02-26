# Enable Garbage Collection Stats
# Per https://docs.newrelic.com/docs/agents/ruby-agent/features/garbage-collection#gc_setup
GC::Profiler.enable

# Add method tracers for methods we're interested in
# https://docs.newrelic.com/docs/agents/ruby-agent/features/ruby-custom-instrumentation#method_tracers
require 'new_relic/agent/method_tracer'

EventsController.class_eval do
  include ::NewRelic::Agent::MethodTracer

  add_method_tracer :process_picture
end


ApplicationController.class_eval do
  include ::NewRelic::Agent::MethodTracer

  add_method_tracer :get_payload_hash

  before_filter do
    ::NewRelic::Agent.add_custom_parameters({ uuid: request.uuid })
  end

end
