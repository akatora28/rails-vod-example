FROM ruby:3.0.2

RUN apt-get update -qq \
    && apt-get install -y ffmpeg nodejs \
    npm

ADD . /app
WORKDIR /app
RUN bundle install
RUN npm install -g yarn
RUN bundle exec rake webpacker:install

EXPOSE 3000
CMD ["bash"]