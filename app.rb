%w[ sinatra
    data_mapper
    dm-postgres-adapter
    bcrypt
    securerandom
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
  
  attr_accessor :password, :password_confirmation
  
  property :id,                           Serial
  property :username,                     String
  property :password_hash,                Text  
  property :password_salt,                Text
  property :token,                        String
  timestamps :created_at, :updated_on

  has n, :annotations
  has n, :annotatable_files
  
  validates_presence_of         :password
  validates_confirmation_of     :password
  
  after :create do
    self.token = SecureRandom.hex
  end

  def generate_token
    self.update!(:token => SecureRandom.hex)
  end
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
  include Rack::Utils
  alias_method :h, :escape_html

  # Convert a hash to a querystring for form population
  def hash_to_query_string(hash)
    hash.delete "password"
    hash.delete "password_confirmation"
    hash.collect {|k,v| "#{k}=#{v}"}.join("&")
  end

  # Redirect to last page or root
  def redirect_last
    if session[:redirect_to]
      redirect_url = session[:redirect_to]
      session[:redirect_to] = nil
      redirect redirect_url
    else
      redirect "/"
    end  
  end

  # Require login to view page
  def login_required
    if session[:user]
      return true
    else
      flash[:notice] =  "Login required to view this page"
      session[:redirect_to] = request.fullpath
      redirect "/login"
      return false
    end
  end

  def current_user
    return @current_user ||= User.first(:token => request.cookies["user"]) if request.cookies["user"]
    @current_user ||= User.first(:token => session[:user]) if session[:user]
  end

  # check if user is logged in?
  def logged_in?
    !!session[:user]
  end

  # Loads partial view into template. Required vriables into locals
  def partial(template, locals = {})
    erb(template, :layout => false, :locals => locals)
  end

  # def current_user 
  #     User.first_or_create( username: "user" )
  #   end

end

# Routes
post '/annotatable-files' do
  redirect to('/')
end

get '/stylesheets/application.css' do
  sass :'sass/application'
end

get '/javascripts/:filename.js' do
  coffee "coffee/#{params[:filename]}".to_sym
end

get '/' do
  haml :index
end

get "/signup" do
  haml :signup
end

post "/signup" do
  user = User.create(params[:user])
  user.password_salt = BCrypt::Engine.generate_salt
  user.password_hash = BCrypt::Engine.hash_secret(params[:user][:password], user.password_salt)
  if user.save
    flash[:info] = "Thank you for registering #{user.username}" 
    session[:user] = user.token
    redirect "/" 
  else
    session[:errors] = user.errors.full_messages
    redirect "/signup?" + hash_to_query_string(params[:user])
  end
end

get "/login" do
  if current_user
    redirect_last
  else
    haml :login
  end
end

post "/login" do
  if user = User.first(:username => params[:username])
    if user.password_hash == BCrypt::Engine.hash_secret(params[:password], user.password_salt)
    session[:user] = user.token 
    response.set_cookie "user", {:value => user.token, :expires => (Time.now + 52*7*24*60*60)} if params[:remember_me]
    redirect_last
    else
      flash[:error] = "User Name/Password combination does not match"
      redirect "/login?username=#{params[:username]}"
    end
  else
    flash[:error] = "That User Name is not recognised"
    redirect "/login?username=#{params[:username]}"
  end
end

get "/logout" do
  current_user.generate_token
  response.delete_cookie "user"
  session[:user] = nil
  flash[:info] = "Successfully logged out"
  redirect "/"
end