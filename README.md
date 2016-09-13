# Academic Commons 2.0

## Checking out and working with a local development instance of Academic Commons 2.0

CURRENT RECOMMENDED VERSION OF RUBY: 1.8.7-p334 (currently running 1.9.3p551 on dev vm)

1. Clone the repository to a location of your choosing
   ```
   git clone git@github.com:cul/ac-academiccommons.git
   ```

2. Checkout the current development branch
   ```
   git checkout {branch}
   ```

3. Create local config files from templates
   ```
   cp config/database.template.yml config/database.yml
   cp config/solr.template.yml config/solr.yml
   cp config/fedora.template.yml config/fedora.yml
   ```

4. Install any needed gems using Rails 3 Bundler
   ```
   bundle install
   ```

5. Run `rake db:schema:load` to create your local development DB. Running `rake db:migrate` does not work because models previously used no longer exist.

6. Start your local development solr instance
   ```
   cd jetty && java -jar start.jar
   ```

7. Populate your Solr instance from Fedora
   ```
   rake ac:reindex[collection:3]
   ```
   **Note: This doesn't seem to work, but I have a feeling it has to do with the parameters.**

8. Start your local Rails app
   ```
   rails server
   ```