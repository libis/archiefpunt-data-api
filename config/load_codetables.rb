$LOAD_PATH << '.' << './lib'

require 'solis'
require 'solis/shape/reader/simple_sheets'
require 'pp'

def encode_id(data)
  data.unpack("H*")[0].to_i(16).to_s(36)
end

def decode_id(data)
  [data.to_i(36).to_s(16)].pack('H*')
end

key = Solis::ConfigFile[:key]
code_table_id = '1jcpRRt13mMlZzUtNntsEE6tA4DZCnzKnzvT8hMf4wkM'

#solis = Solis::Shape::Reader::Sheet.read(key, Solis::ConfigFile[:sheets][:abv], from_cache: true)
solis = Solis::Graph.new(Solis::Shape::Reader::File.read(Solis::ConfigFile[:shape]), Solis::ConfigFile[:solis])
session = SimpleSheets.new(key, code_table_id)
sheets = {}
session.worksheets.each do |worksheet|
  sheet = ::Sheet.new(worksheet)
  sheets[sheet.title] = sheet
end

sheets.each do |tab_name, tab_data|
  puts tab_name
  if solis.shape?(tab_name)
    resource = solis.shape_as_resource(tab_name)

    tab_data.each do |data|
      label = data['label']
      type = data['type']
      definitie = data['definitie']
      query = { "filter" => { "id" => { "eq" => "#{encode_id(label)}" } } }

      if resource.all(query).first.nil?
        Solis::LOGGER.info(label)
        model = solis.shape_as_model(tab_name)

        insert_data = {
          id: encode_id(label),
          identificatie: { id: encode_id(label) },
          label: { id: encode_id(label),
                   term: label,
                   taal: { id: encode_id('nl') }
          }
        }

        unless definitie.empty? || definitie.nil?
          insert_data[:definitie] = {id: encode_id(label),
                                     tekst: definitie,
                                     taal: { id: encode_id('nl') }
          }
        end

        result = model.new(insert_data).save
      else
        Solis::LOGGER.info("\t#{tab_name}(#{label}) exists")
      end
    end
  else
    Solis::LOGGER.error("\t #{tab_name} not found")
  end
end