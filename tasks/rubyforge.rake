require 'rubyforge'
  
class RubyForgeTask

  # Add the following line to your ~/.rubyforge/user-config.yml
  #
  #    <user_config_group>: <your_rubyforge_group_id>
  # 
  def initialize(user_config_group)
    @rubyforge = RubyForge.new()
    @rubyforge.configure
    raise "ERROR: could not find '#{user_config_group}':<your_rubyforge_group_id> in ~/.rubyforge/user-config.yml" unless @rubyforge.userconfig.has_key?(user_config_group)    
    @group_id = @rubyforge.userconfig[user_config_group]
    check_group    
  end
  
  # Uploads a gem to RubyForge 
  #
  # If the release already exists, the user will be prompted
  #
  # == Parameters
  # package_id<String>:: RubyForge package id. (i.e. name of the gem)
  # release_name<String>:: Package release name. (i.e. release version number)
  # file<String>:: path to gem file to upload.
  def upload_gem(package_id, release_name, file)
     puts "Uploading #{file}..."
     
     @rubyforge.create_package(@group_id, package_id) unless package_exists?(package_id)  
     raise "ERROR: release already exists! You must delete first at rubyforge.com" if release_exists?(package_id, release_name) 
  
     @rubyforge.add_release(@group_id, package_id, release_name) 
     @rubyforge.add_file(@group_id, package_id, release_name, file)
  
     puts "done."      
   end
  
  # Deletes an entire package of released files.
  #
  # If the package exists, the user will be prompted before wiping it out.
  #
  # == Parameters
  # package_id<String>:: RubyForge package id. (i.e. name of the gem)
  def delete_package(package_id)
    if package_exists?(package_id)
      continue?("!!WARNING!! This will delete all gems in the '#{package_id}' package.\n  Are you sure?")
      @rubyforge.delete_package(@group_id, package_id) 
    else
      puts "ERROR: Package #{package_id} not found."
    end
  end
  
  # Prompt the user for a yes or no answer.
  # exit if the answer is not "y" or "Y" 
  #
  # @param name [String] The prompt displayed to the user
  def continue?(prompt)
    require 'readline'
    system "stty -echo"
    input = Readline.readline("#{prompt}(y/N): ").strip
    unless (input =~ /[yY]/) then puts "aborted."; exit end 
  ensure
    system "stty echo"
    puts
  end

private   
 
  def check_group
    group_found = @rubyforge.autoconfig["group_ids"][@group_id]
    raise "ERROR: invalid group_id (#{@group_id}).\nHave you run 'rubyforge config' yet?" unless group_found
  end
  
  def package_exists?(package_id)
    @rubyforge.autoconfig["package_ids"].has_key?(package_id)
  end
  
  def release_exists?(package_id, release_name)
    raise "ERROR: invalid package_id: #{package_id}" unless package_exists?(package_id)
    has_release_package = @rubyforge.autoconfig["release_ids"].has_key?(package_id)
    @rubyforge.autoconfig["release_ids"][package_id].has_key?(release_name) if has_release_package
  end

end
  

desc "Release #{GEM} gem to RubyForge"
task :rubyforge_upload do
  gem_repo = RubyForgeTask.new("nanite")
  gem_repo.upload_gem(GEM, Nanite::VERSION, "pkg/#{GEM}-#{Nanite::VERSION}.gem")
end

desc "CAUTION!! Deletes the #{GEM} package to RubyForge."
task :rubyforge_delete do
  gem_repo = RubyForgeTask.new("nanite")
  gem_repo.delete_package(GEM)
end
