# Welcome to Groucho's blog!

Run the docker image and execute the jekyll
`docker run  --volume="$PWD:/srv/jekyll" -it jekyll/jekyll:3.8 /bin/bash`

Create a new repository jekyll
`jekyll new .`

Install the dependencies from the Gemfile
`bundle install`

Execute the jekyll server and bind it to the host
`bundle exec jekyll serve --livereload --host 0.0.0.0`

After the changes are made in the docker container we can commit to a new image
`docker commit <containerID> <nameOfNewImage>`

We can then use the new image just created
`docker run -it  --volume="$PWD:/srv/jekyll" -p 4000:4000 <nameOfNewImage> /bin/bash`

Or to start the server at running use the following command
`docker run -it  --volume="$PWD:/srv/jekyll" -p 4000:4000 groucho_blog bundle exec jekyll serve --livereload --host 0.0.0.0`
