#!/usr/bin/env ruby

framework_path = ARGV[0] || "binaries/**/CoreLitecoin.framework"

Dir.glob("#{framework_path}/**/*.h").each do |src|
  # puts "REWRITING INCLUDES IN #{src}"
  
  data = File.read(src)
  
  #include <openssl/bn.h> => #include <CoreLitecoin/openssl/bn.h>
  data.gsub!(%r{#(include|import) <openssl/}, "#\\1 <CoreLitecoin/openssl/")
  
  #import "BTCSignatureHashType.h" => #import <CoreLitecoin/BTCSignatureHashType.h> 
  data.gsub!(%r{#(include|import) "(BTC.*?\.h)"}, "#\\1 <CoreLitecoin/\\2>")
  
  File.open(src, "w"){|f| f.write(data)}
end
