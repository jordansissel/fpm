require "fpm/namespace"
require "fpm/package"
require "fpm/errors"
require "fpm/util"

# For handling conversion
require "fpm/package/cpan"

class FPM::Package::SRPM < FPM::Package
  def output(output_path)
    source_archive = ::Dir.glob(build_path("*")).select(&File.method(:file?)).first
    source_archive_dirname = `tar -ztf #{Shellwords.escape(source_archive)}` \
      .split("\n").map { |path| path.split("/").first }.uniq.first

    # Generate an rpm spec with Source0: <source_archive>
    rpmspec = template("srpm.erb").result(binding)

    # Copied from rpm.rb ---
    %w(BUILD RPMS SRPMS SOURCES SPECS).each { |d| FileUtils.mkdir_p(build_path(d)) }
    args = ["rpmbuild", "-bs"]

    if %x{uname -m}.chomp != self.architecture
      rpm_target = self.architecture
    end

    # issue #309
    if !attributes[:rpm_os].nil?
      rpm_target = "#{architecture}-unknown-#{attributes[:rpm_os]}"
    end

    # issue #707
    if !rpm_target.nil?
      args += ["--target", rpm_target]
    end

    # set the rpm dist tag
    args += ["--define", "dist .#{attributes[:rpm_dist]}"] if attributes[:rpm_dist]

    args += [
      "--define", "buildroot #{build_path}/BUILD",
      "--define", "_topdir #{build_path}",
      "--define", "_sourcedir #{build_path}",
      "--define", "_rpmdir #{build_path}/RPMS",
      "--define", "_tmppath #{attributes[:workdir]}"
    ]

    args += ["--sign"] if attributes[:rpm_sign?]

    if attributes[:rpm_auto_add_directories?]
      fs_dirs_list = File.join(template_dir, "rpm", "filesystem_list")
      fs_dirs = File.readlines(fs_dirs_list).reject { |x| x =~ /^\s*#/}.map { |x| x.chomp }
      fs_dirs.concat((attributes[:auto_add_exclude_directories] or []))

      Find.find(staging_path) do |path|
        next if path == staging_path
        if File.directory? path and !File.symlink? path
          add_path = path.gsub(/^#{staging_path}/,'')
          self.directories << add_path if not fs_dirs.include? add_path
        end
      end
    else
      self.directories = self.directories.map { |x| self.prefixed_path(x) }
      alldirs = []
      self.directories.each do |path|
        Find.find(File.join(staging_path, path)) do |subpath|
          if File.directory? subpath and !File.symlink? subpath
            alldirs << subpath.gsub(/^#{staging_path}/, '')
          end
        end
      end
      self.directories = alldirs
    end

    # include external config files
    (attributes[:config_files] or []).each do |conf|
      dest_conf = File.join(staging_path, conf)

      if File.exist?(dest_conf)
        logger.debug("Using --config-file from staging area", :path => conf)
      elsif File.exist?(conf)
        logger.info("Copying --config-file from local path", :path => conf)
        FileUtils.mkdir_p(File.dirname(dest_conf))
        FileUtils.cp_r conf, dest_conf
      else
        logger.error("Failed to find given --config-file", :path => conf)
        raise "Could not find config file '#{conf}' in staging area or on host. This can happen if you specify `--config-file '#{conf}'` but this file does not exist in the source package and also does not exist in filesystem."
      end
    end

    # scan all conf file paths for files and add them
    allconfigs = []
    self.config_files.each do |path|
      cfg_path = File.join(staging_path, path)
      raise "Config file path #{cfg_path} does not exist" unless File.exist?(cfg_path)
      Find.find(cfg_path) do |p|
        allconfigs << p.gsub("#{staging_path}/", '') if File.file? p
      end
    end
    allconfigs.sort!.uniq!

    self.config_files = allconfigs.map { |x| File.join("/", x) }

    # add init script if present
    (attributes[:rpm_init_list] or []).each do |init|
      name = File.basename(init, ".init")
      dest_init = File.join(staging_path, "etc/init.d/#{name}")
      FileUtils.mkdir_p(File.dirname(dest_init))
      FileUtils.cp init, dest_init
      File.chmod(0755, dest_init)
    end

    (attributes[:rpm_rpmbuild_define] or []).each do |define|
      args += ["--define", define]
    end

    # copy all files from staging to BUILD dir
    # [#1538] Be sure to preserve the original timestamps.
    Find.find(staging_path) do |path|
      src = path.gsub(/^#{staging_path}/, '')
      dst = File.join(build_path, "BUILD", src)
      copy_entry(path, dst, preserve=true)
    end

    specfile = File.join(build_path("SPECS"), "#{name}.spec")
    File.write(specfile, rpmspec)

    edit_file(specfile) if attributes[:edit?]

    args << specfile

    logger.info("Running rpmbuild", :args => args)
    safesystem(*args)

    ::Dir["#{build_path}/SRPMS/**/*.rpm"].each do |rpmpath|
      # This should only output one rpm, should we verify this?
      FileUtils.cp(rpmpath, output_path)
    end
  end

  def converted_from(origin)
    if origin ==  FPM::Package::CPAN
        # Fun hack to find the instance of the origin class
        # So we can find the build_path
        input = nil
        ObjectSpace.each_object { |x| input = x if x.is_a?(origin) }
        if input.nil?
            raise "Something bad happened. Couldn't find origin package in memory? This is a bug."
        end

        # Pick the first file found, should be a tarball.
        source_archive = ::Dir.glob(File.join(input.build_path, "*")).select(&File.method(:file?)).first
        #FileUtils.copy_entry(source_archive, build_path)
        File.link(source_archive, build_path(File.basename(source_archive)))
        #FileUtils.copy_entry(source_archive, build_path)
    end
  end

  def summary
    if !attributes[:rpm_summary]
      return @description.split("\n").find { |line| !line.strip.empty? } || "_"
    end

    return attributes[:rpm_summary]
  end # def summary

  def prefix
    if attributes[:prefix] and attributes[:prefix] != '/'
      return attributes[:prefix].chomp('/')
    else
      return "/"
    end
  end # def prefix

  def to_s(format=nil)
    if format.nil?
      format = if attributes[:rpm_dist]
        "NAME-VERSION-ITERATION.DIST.src.rpm"
      else
        "NAME-VERSION-ITERATION.src.rpm"
      end
    end
    return super(format.gsub("DIST", to_s_dist))
  end # def to_s

  def to_s_dist
    attributes[:rpm_dist] ? "#{attributes[:rpm_dist]}" : "DIST";
  end

  # This method ensures a default value for iteration if none is provided.
  def iteration
    if @iteration.kind_of?(String) and @iteration.include?("-")
      logger.warn("Package iteration '#{@iteration}' includes dashes, converting" \
                   " to underscores. rpmbuild does not allow the dashes in the package iteration (called 'Release' in rpm)")
      @iteration = @iteration.gsub(/-/, "_")
    end

    return @iteration ? @iteration : 1
  end # def iteration

  def version
    if @version.kind_of?(String) and @version.include?("-")
      logger.warn("Package version '#{@version}' includes dashes, converting" \
                   " to underscores")
      @version = @version.gsub(/-/, "_")
    end

    return @version
  end

  # The default epoch value must be nil, see #381
  def epoch
    return @epoch if @epoch.is_a?(Numeric)

    if @epoch.nil? or @epoch.empty?
      return nil
    end

    return @epoch
  end # def epoch

  # Handle any architecture naming conversions.
  # For example, debian calls amd64 what redhat calls x86_64, this
  # method fixes those types of things.
  def architecture
    case @architecture
      when nil
        return %x{uname -m}.chomp   # default to current arch
      when "amd64" # debian and redhat disagree on architecture names
        return "x86_64"
      when "arm64" # debian and redhat disagree on architecture names
        return "aarch64"
      when "native"
        return %x{uname -m}.chomp   # 'native' is current arch
      when "all"
        # Translate fpm "all" arch to what it means in RPM.
        return "noarch"
      else
        return @architecture
    end
  end # def architecture

  public(:output)
end # class FPM::Target::Deb
