module Sinatra
  module MainHelper
    def endpoints
      settings.archiefbank.list_shapes.map {|m| "/#{m.tableize}"}.sort
    end

    def api_error(status, source, title="Unknown error", detail="")
      {"errors": [{
                    "status": status,
                    "source": {"pointer":  source},
                    "title": title,
                    "detail": detail
                  }]}
    end

    def for_resource
      entity = params[:entity]
      halt 404, api_error('404', request.url, "Not found", "Available endpoints: #{endpoints.join(', ')}") if endpoints.grep(/#{entity}/).empty?
      klass="#{entity.singularize.classify}"
      settings.archiefbank.shape_as_resource(klass)
    end

    def for_model
      entity = params[:entity]
      halt 404, api_error('404', request.url, "Not found", "Available endpoints: #{endpoints.join(', ')}") if endpoints.grep(/#{entity}/).empty?
      klass="#{entity.singularize.classify}"
      settings.archiefbank.shape_as_model(klass)
    end

    def audit_request
      return if endpoints.grep(/#{request.path_info}/).empty?

      m = request.request_method
      ip = request.ip
      entity = request.path_info.gsub(/^\/+/,'')
      user = ''
      audit = {ip: ip, action: m, entity: entity, user: user, timestamp: Time.now}
      settings.auditor << audit
    rescue Exception => e
      Solis::LOGGER.error('Unable to write audit')
    end
  end
  helpers MainHelper
end