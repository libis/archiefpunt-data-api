require_relative 'generic_controller'

class MainController < GenericController

  configure do
    #    set :archiefbank_queue, RedisQueue.new("archiefbank")
    set :archiefbank, Solis::Graph.new(Solis::Shape::Reader::File.read(Solis::ConfigFile[:shape]), Solis::ConfigFile[:solis])
  end

  get '/' do
    content_type :json
    endpoints.to_json
  rescue StandardError => e
    halt 500, api_error('500', request.url, "Unknown Error", e.message)
  end

  get '/vandal/?' do
    File.read('public/vandal/index.html')
  rescue StandardError => e
    halt 500, api_error('500', request.url, "Unknown Error", e.message)
  end

  get '/schema.json' do
    content_type :json
    Graphiti::Schema.generate.to_json
  rescue StandardError => e
    halt 500, api_error('500', request.url, "Unknown Error", e.message)
  end

  get '/:entity' do
    content_type :json
    for_resource.all(params.merge({stats: {total: :count}})).to_jsonapi
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, "Not found", "'#{id}' niet gevonden in  #{params[:entity]}").to_json
  rescue StandardError => e
    puts e.backtrace.join("\n")
    content_type :json
    halt 500, api_error(response.status, request.url, "Unknown Error", e.message).to_json
  end

  post '/:entity' do
    result = nil
    data = JSON.parse(request.body.read)
    if params[:queue]
      r = settings.archiefbank_queue.push({params: params, data: data})
      result = {queue: r}.to_json
    else
      model = for_model.new(data['attributes'])
      model.save
      result = for_resource.find({id: model.id}).to_jsonapi
    end
    result
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, "Not found", "'#{id}' niet gevonden in  #{params[:entity]}").to_json
  rescue StandardError => e
    content_type :json
    halt 500, api_error(response.status, request.url, "Unknown Error", e.message).to_json
  end

  get '/:entity/model' do
    content_type :json
    if params.key?(:template) && params[:template]
      for_model.model_template.to_json
    else
      for_model.model.to_json
    end
  rescue StandardError => e
    content_type :json
    halt 500, api_error(response.status, request.url, "Unknown Error", e.message).to_json
  end

  put '/:entity' do
    content_type :json
    data = JSON.parse(request.body.read)
    resource = for_model.new.update(data)

    for_resource.find({id: resource.id}).to_jsonapi
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, "Not found", "'#{id}' niet gevonden in  #{params[:entity]}").to_json
  rescue StandardError => e
    content_type :json
    puts e.backtrace.join("\n")
    halt 500, api_error(response.status, request.url, "Unknown Error", e.message).to_json
  end

  delete '/:entity' do
    content_type :json
    data = JSON.parse(request.body.read)
    #resource = for_resource.find(data)

    resource = for_resource.find({id: data.id}).data
    resource.destroy
    resource
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, "Not found", "'#{id}' niet gevonden in  #{params[:entity]}").to_json
  rescue StandardError => e
    content_type :json
    puts e.backtrace.join("\n")
    halt 500, api_error(response.status, request.url, "Unknown Error", e.message).to_json
  end


  get '/:entity/:id' do
    content_type :json
    id = params.delete(:id)
    data = {id: id}
    data = data.merge(params)
    for_resource.find(data).to_jsonapi
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, "Not found", "'#{id}' niet gevonden in  #{params[:entity]}").to_json
  rescue StandardError => e
    content_type :json
    halt 500, api_error(response.status, request.url, "Unknown Error", e.message).to_json
  end
end