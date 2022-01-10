# frozen_string_literal: true

require_relative 'generic_controller'
require 'hashdiff'

class MainController < GenericController
  configure do
    set :archiefbank_audit_queue, RedisQueue.new("archiefbank")
    set :archiefbank, Solis::Graph.new(Solis::Shape::Reader::File.read(Solis::ConfigFile[:shape]),
                                       Solis::ConfigFile[:solis].merge({
                                                                         hooks: {
                                                                           create: {
                                                                             before: lambda do |model, data|
                                                                               n = {}
                                                                               data[:new].instance_variable_names.each do |m|
                                                                                 n[m.gsub(/^@/, '')] =
                                                                                   data[:new].instance_variable_get(m)
                                                                               end

                                                                               diff = Hashdiff.best_diff({}, n)

                                                                               unless diff.empty?
                                                                                 new_data = {
                                                                                   entity: {
                                                                                     id: model.id,
                                                                                     name: model.name,
                                                                                     name_plural: model.name(true),
                                                                                     graph: model.class.graph_name
                                                                                   },
                                                                                   diff: diff,
                                                                                   timestamp: Time.now,
                                                                                   user: 'unknown'
                                                                                 }

                                                                                 settings.archiefbank_audit_queue.push(new_data)
                                                                               end
                                                                             end
                                                                           },
                                                                           delete: {
                                                                             before: lambda do |model, data|
                                                                               n = {}
                                                                               data[:new].instance_variable_names.each do |m|
                                                                                 n[m.gsub(/^@/, '')] =
                                                                                   data[:new].instance_variable_get(m)
                                                                               end

                                                                               diff = Hashdiff.best_diff(n, {})
                                                                               unless diff.empty?
                                                                                 new_data = {
                                                                                   entity: {
                                                                                     id: model.id,
                                                                                     name: model.name,
                                                                                     name_plural: model.name(true),
                                                                                     graph: model.class.graph_name
                                                                                   },
                                                                                   diff: diff,
                                                                                   timestamp: Time.now,
                                                                                   user: 'unknown'
                                                                                 }

                                                                                 settings.archiefbank_audit_queue.push(new_data)
                                                                               end
                                                                             end
                                                                           },
                                                                           update: {
                                                                             before: lambda do |model, data|
                                                                               o = {}
                                                                               data[:old].instance_variable_names.each do |m|
                                                                                 o[m.gsub(/^@/, '')] =
                                                                                   data[:old].instance_variable_get(m)
                                                                               end
                                                                               n = {}
                                                                               data[:new].instance_variable_names.each do |m|
                                                                                 n[m.gsub(/^@/, '')] =
                                                                                   data[:new].instance_variable_get(m)
                                                                               end

                                                                               diff = Hashdiff.best_diff(o, n)

                                                                               unless diff.empty?
                                                                                 new_data = {
                                                                                   entity: {
                                                                                     id: model.id,
                                                                                     name: model.name,
                                                                                     name_plural: model.name(true),
                                                                                     graph: model.class.graph_name
                                                                                   },
                                                                                   diff: Hashdiff.diff(o, n),
                                                                                   timestamp: Time.now,
                                                                                   user: 'unknown'
                                                                                 }

                                                                                 settings.archiefbank_audit_queue.push(new_data)
                                                                                 pp new_data
                                                                               end
                                                                             end
                                                                           }
                                                                         }
                                                                       }))
  end

  get '/' do
    content_type :json
    endpoints.to_json
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'Unknown Error', e.message)
  end

  get '/vandal/?' do
    File.read('public/vandal/index.html')
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'Unknown Error', e.message)
  end

  get '/yas/?' do
    erb :'yas/index.html', locals: { sparql_endpoint: Solis::ConfigFile[:solis][:env][:sparql_endpoint] }
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'Unknown Error', e.message)
  end

  get '/schema.json' do
    content_type :json
    Graphiti::Schema.generate.to_json
  rescue StandardError => e
    halt 500, api_error('500', request.url, 'Unknown Error', e.message)
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
    resource = for_model.new.update(data)

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
