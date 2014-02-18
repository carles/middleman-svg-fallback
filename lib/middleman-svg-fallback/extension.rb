require 'rake'
module Middleman
    module SVGFallback
        class << self
        
            def registered(app, options={})
                
                app.after_configuration do
                    defaults = Proc.new { |opts| opts.find {|x| !x.nil? }}
                    options[:inkscape_bin] = defaults.call([options[:inkscape_bin], data.svg_fallbacks.inkscape_bin, 'inkscape'])
                    options[:inkscape_options] = defaults.call([options[:inkscape_options], data.svg_fallbacks.inkscape_options, nil])
                    options[:generate_svgz] = defaults.call([options[:generate_svgz], data.svg_fallbacks.generate_svgz, true])
                    options[:generate_jpeg] = defaults.call([options[:generate_jpeg], data.svg_fallbacks.generate_jpeg, true])
                    options[:generate_png] = defaults.call([options[:generate_png], data.svg_fallbacks.generate_png, true])
                    options[:jpeg_extension] = defaults.call([options[:jpeg_extension], data.svg_fallbacks.jpeg_extension, "jpg"])
                    
                    input_dir = defaults.call([options[:input_folder], data.svg_fallbacks.input_folder, images_dir])
                    input_dir = File.join(source_dir, input_dir).chomp("/")
                    raise "Could not find source folder #{input_dir}" unless File.directory?(input_dir)
          
                    output_dir = defaults.call([options[:output_folder], data.svg_fallbacks.output_folder, nil])
                    output_dir = output_dir.nil? ? input_dir : File.join(source_dir, output_dir).chomp("/")
                    raise "Could not find output folder #{output_dir}" unless File.directory?(output_dir)

                    before_build do |builder|
                        files = FileList["#{input_dir}/**/*.svg*"]
          
                        files.each do |file|
                            # make sure we have both an svg and an svgz version
                            path_without_extension = file.sub(/\.svgz?$/,'')
                                      
                            temp_uncompressed_file = nil
                            unless File.exists? "#{path_without_extension}.svg"
                                `gunzip --to-stdout --suffix .svgz  #{path_without_extension}.svgz > #{path_without_extension}.svg`
                                temp_uncompressed_file = "#{path_without_extension}.svg"
                            end
                            
                            if options[:generate_svgz] && !File.exists?("#{path_without_extension}.svgz")
                                `gzip --to-stdout #{path_without_extension}.svg > #{path_without_extension}.svgz`
                                builder.say_status :svgz, "#{path_without_extension}.svgz"
                            end
          
                            file_dimensions = data.svg_fallbacks.dimensions.find { |f| File.expand_path(f.filepath, input_dir) == file }
                            dimensions = []
                            if file_dimensions && file_dimensions.multiple
                                dimensions += file_dimensions.multiple
                            elsif file_dimensions
                                dimensions << {width: file_dimensions.width, height: file_dimensions.height}
                            end
          
                            # generate fallbacks
                            raster_images = []
                            raster_images << "png" if options[:generate_png]
                            raster_images << options[:jpeg_extension] if options[:generate_jpeg]
                            raster_images.each do |ext|
                                input_path = "#{path_without_extension}.svg" 
                                command = "#{options[:inkscape_bin]}"
                                command = "#{command} #{options[:inkscape_options]}" if options[:inkscape_options]
                                
                                if dimensions.count > 0
                                    for d in dimensions
                                        command = "#{command} --export-width=#{d[:width]} --export-height=#{d[:height]}"
                                        output_path = "#{File.join(output_dir, File.basename(path_without_extension))}_#{d[:width]}x#{d[:height]}.#{ext}"
                                        command = "#{command} --export-png=#{output_path}"
                                        command = "#{command} --without-gui #{input_path} > /dev/null 2>&1"
                                        system command
                                        builder.say_status :svg_fallback, "#{output_path}"
                                    end
                                else
                                    output_path = "#{File.join(output_dir, File.basename(path_without_extension))}.#{ext}"
                                    command = "#{command} --export-png=#{output_path}"
                                    command = "#{command} --without-gui #{input_path} > /dev/null 2>&1"
                                    system command
                                    builder.say_status :svg_fallback, "#{output_path}"
                                end 
                            end
                            
                            if !options[:generate_svgz] && temp_uncompressed_file
                                File.rm(temp_uncompressed_file)
                            end
                        end
                    end
                end
            end
            alias :included :registered
      
        end
    end
end