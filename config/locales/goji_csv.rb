# This file gets evaluated, and all we have to yield out is a hash, starting with the locale
# Any logic to format it how we want it can happen here
raw = CSV.parse(File.read(Rails.root.join("config/locales/en.csv")))
result = {}
raw.each do |raw_key, value|
  # NAMESPACE_KEY_NAME is the format
  # .intern converts to symbols
  idx       = raw_key.index("_")
  namespace = raw_key[0..idx-1].intern
  key       = raw_key[idx+1..raw_key.length].intern

  # ||={} creates the sub hash if it doesn't exist
  # gsub is replacing $[var] with %{var}, could correct in source
  (result[namespace] ||={})[key] = value.gsub(/\$\[([^\]]+)\]/,'%{\1}')
end

{en: result}
