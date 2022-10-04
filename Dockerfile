FROM jekyll/jekyll


COPY --chown=jekyll:jekyll Gemfile .

#RUN bundle clean --force
RUN bundle install --quiet

#CMD ["jekyll", "serve", "--livereload", "--host", "0.0.0.0"]