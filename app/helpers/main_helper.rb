module Sinatra
  module MainHelper
    def endpoints
      settings.solis.list_shapes.map {|m| "/#{m.tableize}"}.sort
    end

    def api_error(status, source, title="Unknown error", detail="")
      content_type :json
      {"errors": [{
                    "status": status,
                    "source": {"pointer":  source},
                    "title": title,
                    "detail": detail
                  }]}.to_json
    end

    def for_resource
      entity = params[:entity]
      halt 404, api_error('404', request.url, "Not found", "Available endpoints: #{endpoints.join(', ')}").to_json if endpoints.grep(/#{entity}/).empty?
      klass="#{entity.singularize.classify}"
      settings.solis.shape_as_resource(klass)
    end

    def for_model
      entity = params[:entity]
      halt 404, api_error('404', request.url, "Not found", "Available endpoints: #{endpoints.join(', ')}").to_json if endpoints.grep(/#{entity}/).empty?
      klass="#{entity.singularize.classify}"
      settings.solis.shape_as_model(klass)
    end

    def recursive_compact(hash_or_array)
      p = proc do |*args|
        v = args.last
        v.delete_if(&p) if v.respond_to? :delete_if
        v.nil? || v.respond_to?(:"empty?") && v.empty?
      end

      hash_or_array.delete_if(&p)
    end
  end
  helpers MainHelper
end