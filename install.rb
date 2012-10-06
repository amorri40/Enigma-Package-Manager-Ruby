#!/usr/bin/ruby
# Ruby version of the Enigma installer/package manager

require 'open-uri'
require 'optparse'
require 'pathname'
require 'fileutils'
require 'digest/md5'
require 'rubygems'
require 'zip/zip'


puts "Enigma Package Manager"
url="https://raw.github.com/enigma-dev/Enigma-packages/master/packages.md5"
$updateText= open(url){|f|f.read}.split("\n")
puts $updateText

$g_packageToInstall="main"
$g_packageToShow=""
$g_currentPackage="main"

#get the Operating system 
$g_OS=RUBY_PLATFORM.downcase
if $g_OS.include?("darwin"): g_OS="darwin"
    elsif $g_OS.include?("mswin"): g_OS="win32"
    elsif $g_OS.include?("linux"): g_OS="lin32"
    else $g_OS=""
end

$g_globalInstall=false
$g_showOnly=false
$g_installLocation="./"

#Handle command line options
OptionParser.new do |opts|
    opts.banner = "Usage: install.rb [options] \n"+"    To see all packages use --show=all \n    To install globally use --global (useful for large sdks) \n    To see all packages in a category use --show=categoryname"
    opts.on("-s", "--show [Category]", "Show Packages") do |cat|
        cat="" if cat==nil
        p cat
        $g_packageToInstall=""; $g_packageToShow=cat; $g_showOnly=true
    end
    
    opts.on("-p [Package]","--package [Package]","Install Package") do |package|
        p "package to install:"+package
        $g_packageToInstall=package
    end
    
    opts.on_tail("-h", "--help", "Show this message") do
        puts opts #print the help message
        exit
    end
end.parse!

if (ARGV.length==1): $g_packageToInstall=ARGV[0] end

if $g_packageToInstall.end_with?("SDK"): $g_packageToInstall+="-"+$g_OS end #SDKs are platform specific

puts ("Installing "+$g_packageToInstall+" please wait...") if not $g_showOnly

# ensure_dir will make any folders which don't yet exist
# * *Args*    :
#   - +f+ -> the file url you want to make sure exists
#
def ensure_dir(f)
    d = Pathname.new(f).dirname
    FileUtils.mkdir_p(d) if not Pathname.new(d).exist?
end

# extract_epackage will treat .epackage files as zips and extract the data to the same directory
# * *Args*    :
#   - +epackage+ -> the path to the .epackage file you want to extract
#
def extract_epackage(epackage)
    puts ("INFO: Extracting "+epackage)
    epackage_dir=File.dirname(epackage)
    Zip::ZipFile.open(epackage) { |zip|
       zip.each { |fi|
         f_path=File.join(epackage_dir, fi.name)
         FileUtils.mkdir_p(File.dirname(f_path))
         zip.extract(fi, f_path) unless File.exist?(f_path)
       }
      }
    FileUtils.rmtree(File.join(epackage_dir,"__MACOSX"))
end


# downloadPackage is the starting point for the script, it will download and install the package and
# related dependencies
# * *Args*    :
#   - +packageToInstall+ -> the package you wish to install
#
def downloadPackage(packageToInstall)
    show_iterator=1 #only used with the show argument to neatly print out number of package's
    for package in $updateText:
        
        if package.start_with?("#Category:"): $g_currentPackage=package.split(" ")[0][10..-1]; next end
        if (package.length < 1) or package.start_with?("#"): next end
        
        #split the pakage into its components
                packageProperties=package.split(" ")
                packageName = packageProperties[0]
                packageHash = packageProperties[1]
                packageLocalPath = packageProperties[2]
                packageURL = packageProperties[3]
                packageDeps = packageProperties[4]
                
        #display this packed (if in show mode)
        if $g_currentPackage == $g_packageToShow or $g_packageToShow=='all': puts(show_iterator.to_s+") "+packageName); show_iterator+=1 end
                
        if packageName != packageToInstall: next end
        
        #loop through dependencies and download them
                for dependency in packageDeps.split(","):
                    if dependency == "none": puts("INFO: no dependencies for "+packageName); break end
                    downloadPackage(dependency)
                end

       begin
           ensure_dir($g_installLocation+packageLocalPath)
           localfile=File.open($g_installLocation+packageLocalPath, 'rb')
           file_contents=localfile.read()
           localfile.close()
           if Digest::MD5.hexdigest(file_contents) == packageHash: 
              puts("INFO: "+packageName + " already up-to-date (same hash)")
              break #exit now that we have what we are looking for
           else 
              puts("INFO: "+packageName+" hash did not match (probably needs updated) localhash:"+Digest::MD5.hexdigest(file_contents)+ " remotehash:"+packageHash)
           end
       rescue Errno::ENOENT => e
                puts "INFO: File doesn't exist so downloading:"+packageLocalPath
       end
       
       # now do the actual downloading of the file
       webFile = open(packageURL)
       localfile=File.open($g_installLocation+packageLocalPath, 'wb')
       localfile.write(webFile.read())
       localfile.close()
       webFile.close()
    
       if packageLocalPath.end_with?(".epackage"): extract_epackage($g_installLocation+packageLocalPath) end
                
    end
end

    
downloadPackage($g_packageToInstall)
if $g_showOnly: puts("Finished showing all packages for category: "+$g_packageToShow)
else puts("Finished updating "+$g_packageToInstall) end