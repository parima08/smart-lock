desc "Regenerate tags (CTAGS)"
task :ctags do
  puts " * Regenerating Tags"
  excludes = %w{
    .git
    app/views/
    coverage
    doc
    features
    log
    tmp
    vendor
  }
  excludes_options = excludes.map{|e| "--exclude=#{e}"}.join(' ')
  system("ctags -V -a -R #{excludes_options} * `gem environment | grep INSTALLATION | awk '{print $4}'`/*")
end

