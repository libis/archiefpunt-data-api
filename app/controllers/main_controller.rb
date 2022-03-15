# frozen_string_literal: true
require 'http'
require 'hashdiff'
require_relative 'generic_controller'

class MainController < GenericController
  get '/' do
    content_type :json
    endpoints.to_json
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'Unknown Error', e.message).to_json
  end

  get '/_vandal/?' do
    #File.read('public/vandal/index.html')
    redirect to('/_vandal/index.html')
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'Unknown Error', e.message).to_json
  end

  get '/_doc/?' do
    redirect to('/_doc/index.html')
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'Unknown Error', e.message).to_json
  end

  get '/_yas/?' do
    # erb :'yas/index.html', locals: { sparql_endpoint: '/_sparql' }
    redirect to('/_yas/index.html')
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'Unknown Error', e.message).to_json
  end

  get '/_sparql/?' do
    content_type :json
    halt 501, api_error('501', request.url, 'SparQL error', 'Only POST queries are supported').to_json
  end

  post '/_sparql' do
    content_type 'application/x-turtle'
    result = ''
    data = request.body.read

    halt 501, api_error('501', request.url, 'SparQL error', 'INSERT, UPDATE, DELETE not allowed').to_json unless data.match(/clear|drop|insert|update|delete/i).nil?

    url = "#{Solis::ConfigFile[:solis][:sparql_endpoint]}?#{data}"

    response = HTTP.get(url)
    if response.status == 200
      result = response.body.to_s
    elsif response.status == 500
      halt 500, api_error('500', request.url, 'SparQL error', response.body.to_s).to_json
    else
      halt response.status, api_error(response.status.to_s, request.url, 'SparQL error', response.body.to_s).to_json
    end

    result
  rescue HTTP::Error => e
    halt 500, api_error('500', request.url, 'SparQL error', e.message).to_json
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'SparQL error', e.message).to_json
  end

  get '/schema.json' do
    content_type :json
    Graphiti::Schema.generate.to_json
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'Unknown Error', e.message).to_json
  end

  get '/:entity' do
    content_type :json
    # recursive_compact(JSON.parse(for_resource.all(params.merge({stats: {total: :count}})).to_jsonapi)).to_json
    for_resource.all(params.merge({ stats: { total: :count } })).to_jsonapi
  rescue Solis::Error::InvalidAttributeError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Invalid attribute', e.message).to_json
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, 'Not found', "'#{id}' niet gevonden in  #{params[:entity]}").to_json
  rescue StandardError => e
    puts e.backtrace.join("\n")
    content_type :json
    halt 500, api_error(response.status, request.url, 'Unknown Error', e.message).to_json
  end

  post '/:entity' do
    content_type :json
    result = nil
    data = JSON.parse(request.body.read)

    model = for_model.new(data['attributes'])
    model.save
    result = for_resource.find({ id: model.id }).to_jsonapi
    result
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, 'Not found', "'#{id}' niet gevonden in  #{params[:entity]}").to_json
  rescue Solis::Error::InvalidAttributeError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Invalid attribute', e.message).to_json
  rescue StandardError => e
    content_type :json
    puts e.message
    puts e.backtrace.join("\n")
    halt 500, api_error(response.status, request.url, 'Unknown Error', e.message).to_json
  end

  get '/:entity/model' do
    content_type :json
    if params.key?(:template) && params[:template]
      for_model.model_template.to_json
    else
      for_model.model.to_json
    end
  rescue Solis::Error::InvalidAttributeError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Invalid attribute', e.message).to_json
  rescue StandardError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Unknown Error', e.message).to_json
  end

  put '/:entity/:id' do
    content_type :json
    resource = for_resource.find({ id: params['id'] })
    raise Graphiti::Errors::RecordNotFound unless resource

    data = JSON.parse(request.body.read)
    resource = for_model.new.update(data,
                                    params.key?(:validate_dependencies) ? !params[:validate_dependencies].eql?('false') : true)

    for_resource.find({ id: resource.id }).to_jsonapi
  rescue Solis::Error::InvalidAttributeError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Invalid attribute', e.message).to_json
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, 'Not found', "'#{id}' niet gevonden in  #{params[:entity]}").to_json
  rescue StandardError => e
    content_type :json
    puts e.backtrace.join("\n")
    halt 500, api_error(response.status, request.url, 'Unknown Error', e.message).to_json
  end

  delete '/:entity/:id' do
    content_type :json
    resource = for_resource.find({ id: params['id'] })
    raise Graphiti::Errors::RecordNotFound unless resource

    resource.data.destroy
    resource.to_jsonapi
  rescue Solis::Error::InvalidAttributeError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Invalid attribute', e.message).to_json
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, 'Not found', "'#{id}' niet gevonden in  #{params[:entity]}").to_json
  rescue StandardError => e
    content_type :json
    puts e.backtrace.join("\n")
    halt 500, api_error(response.status, request.url, 'Unknown Error', e.message).to_json
  end

  get '/:entity/:id' do
    content_type :json
    id = params.delete(:id)
    data = { id: id }
    data = data.merge(params)
    for_resource.find(data).to_jsonapi
  rescue Solis::Error::InvalidAttributeError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Invalid attribute', e.message).to_json
  rescue Graphiti::Errors::RecordNotFound
    content_type :json
    halt 404, api_error('404', request.url, 'Not found', "'#{id}' niet gevonden in  #{params[:entity]}").to_json
  rescue StandardError => e
    content_type :json
    halt 500, api_error(response.status, request.url, 'Unknown Error', e.message).to_json
  end
end
