%w[ sinatra
    data_mapper
    dm-postgres-adapter
    haml sass coffee-script ].each { |dep| require dep }


# Config
configure :development do
  DataMapper.setup(:default, {
    :adapter  => 'postgres',
    :host     => 'localhost',
    :username => '' ,
    :password => '',
    :database => 'footnote_development'
  })

  DataMapper::Logger.new(STDOUT, :debug)
end


# Models
class User
  include DataMapper::Resource

  property :id, Serial
  property :username, String
  timestamps :created_at, :updated_on

  has n, :annotations
  has n, :annotatable_files
end


class AnnotatableFile
  include DataMapper::Resource

  property :id, Serial
  property :filename, String
  property :title, String
  property :description, Text
  timestamps :created_at, :updated_on

  has n, :annotations
end


class Annotation
  include DataMapper::Resource

  property :id, Serial
  property :body, Text
  timestamps :created_at, :updated_on

  belongs_to :user
  belongs_to :annotatable_file
end

# Migrations, etc
DataMapper.auto_upgrade!
DataMapper.finalize

helpers do
  def current_user 
    User.first_or_create( username: "user" )
  end
end

# Routes
post '/annotatable-files' do
  @annotatable_file = current_user.annotatable_files.create(params[:annotatable_file])
  redirect to('/')
end

get '/stylesheets/application.css' do
  sass :'sass/application'
end

get '/javascripts/:filename.js' do
  coffee "coffee/#{params[:filename]}".to_sym
end

get '/' do
  @annotatable_file = current_user.annotatable_files.last
  haml :index
end
