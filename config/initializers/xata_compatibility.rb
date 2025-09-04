# Xata database compatibility
# Xata doesn't support CREATE EXTENSION statements but has plpgsql enabled by default

# Prevent extension enabling when using Xata
if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
  module XataExtensionPrevention
    def enable_extension(name, **)
      # Skip enabling extensions on Xata (they're already enabled)
      return if ENV["DATABASE_URL"]&.include?("xata.sh")
      super
    end
  end

  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(XataExtensionPrevention)
end

# Hook into migration tasks to fix schema.rb after it's generated
if defined?(Rails) && Rails.env.production?
  # In production (on Render with Xata), automatically fix the schema file
  namespace :db do
    task :fix_schema_for_xata do
      if ENV["DATABASE_URL"]&.include?("xata.sh")
        schema_file = Rails.root.join("db", "schema.rb")
        if File.exist?(schema_file)
          content = File.read(schema_file)
          # Comment out the enable_extension line
          fixed_content = content.gsub(
            /^(\s*)enable_extension "pg_catalog\.plpgsql"$/,
            '\1# enable_extension "pg_catalog.plpgsql" # Disabled for Xata - plpgsql is enabled by default'
          )
          File.write(schema_file, fixed_content)
        end
      end
    end
  end
  
  # Run after schema:dump or schema:load
  Rake::Task["db:schema:dump"].enhance do
    Rake::Task["db:fix_schema_for_xata"].invoke
  end if defined?(Rake::Task["db:schema:dump"])
end
