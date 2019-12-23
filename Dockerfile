FROM jekyll/jekyll

COPY --chown=jekyll:jekyll Gemfile .
COPY --chown=jekyll:jekyll Gemfile.lock .

RUN bundle install --quiet --clean

#CMD ["jekyll", "serve", "--livereload", "--host", "0.0.0.0"]
