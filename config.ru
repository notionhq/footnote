require './app'
require "sinatra"
require "sinatra/flash"

enable :sessions

run Sinatra::Application
