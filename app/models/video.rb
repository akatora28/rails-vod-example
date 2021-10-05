class Video < ApplicationRecord
    include VideoUploader::Attachment(:original_video)
end
