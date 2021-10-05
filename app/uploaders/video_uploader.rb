class VideoUploader < Shrine
    plugin :versions
    plugin :processing

    def initialize(*args)
        super
        @@_uuid = SecureRandom.uuid
    end

    def generate_location(io, record: nil, **)
        basename, extname = super.split(".")
        # Since multiple .ts files are generated, just using {@@_uuid}/@@_uuid.extname.to_s
        # will overwrite the file each time it saves the new one. This also retains the number at
        # the end of the .ts filename for the m3u8 playlist to keep track
        if extname == 'ts' || extname == 'm3u8'
            location = "#{@@_uuid}/#{File.basename(io.to_path)}"
        else
            location = "#{@@_uuid}/#{@@_uuid}.#{extname.to_s}"
        end
    end

    def generate_hls_playlist(movie, path, uuid, width, bitrate, master_playlist)
        ffmpeg_options = {validate: false, custom: %W(-profile:v baseline -level 3.0 -vf scale=#{width}:-2 -b:v #{bitrate} -start_number 0 -hls_time 2 -hls_list_size 0 -f hls) }
        transcoded_movie = movie.transcode(File.join("#{path}", "#{uuid}-w#{width}-#{bitrate}.m3u8"), ffmpeg_options)
        
        bandwidth = 0
        avg_bandwidth = 0
        avg_bandwidth_counter = 0
        
        Dir.glob("#{path}/#{uuid}-w#{width}-#{bitrate}*.ts") do |ts|
            movie = FFMPEG::Movie.new(ts)
            if movie.bitrate > bandwidth
                bandwidth = movie.bitrate
            end
            avg_bandwidth += movie.bitrate
            avg_bandwidth_counter += 1
        end

        avg_bandwidth = (avg_bandwidth / avg_bandwidth_counter)

        master_playlist.write("#EXT-X-STREAM-INF:BANDWIDTH=#{bandwidth},AVERAGE-BANDWIDTH=#{avg_bandwidth},CODECS=\"avc1.640028,mp4a.40.5\",RESOLUTION=#{transcoded_movie.resolution},FRAME-RATE=#{transcoded_movie.frame_rate.to_f}\n")
        master_playlist.write(File.join("/uploads", uuid, "#{File.basename(transcoded_movie.path)}\n") )
    end

    process(:store) do |io, **options|
        versions = { original: io, hls_playlist: [] }
        
        io.download do |original|
            path = File.join(Rails.root, "tmp", "#{@@_uuid}")
            FileUtils.mkdir_p(path) unless File.exist?(path)

            movie = FFMPEG::Movie.new(original.path)

            # Master m3u8 playlist
            master_playlist = File.open(File.join("#{path}","#{@@_uuid}-master.m3u8"), "w")
            master_playlist.write("#EXTM3U\n")
            master_playlist.write("#EXT-X-VERSION:3\n")
            master_playlist.write("#EXT-X-INDEPENDENT-SEGMENTS\n")

            generate_hls_playlist(movie, path, @@_uuid, 720, "2000k", master_playlist)
            generate_hls_playlist(movie, path, @@_uuid, 1080, "4000k", master_playlist)

            # Add the master_playlist as first item in :hls_playlist array
            versions[:hls_playlist] << File.open(master_playlist.path)

            # Match the .m3u8 playlists for various resolutions / bitrates & make sure they get 
            # added to storage
            Dir.glob("#{path}/#{@@_uuid}-w*.m3u8") do |m3u8|
                versions[:hls_playlist] << File.open(m3u8)
            end
            Dir.glob("#{path}/#{@@_uuid}*.ts").each do |ts|
                versions[:hls_playlist] << File.open(ts)
            end

            # Finish writing master playlist
            master_playlist.close
            # Clean up tmp/ folder after processing is finished
            FileUtils.rm_rf("#{path}")
        end
        versions
    end
end