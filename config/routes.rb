Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Landing: concept explainer + list of games
  root "home#index"

  # Group Group Chat.
  # GET  /ggc            new session form
  # POST /ggc            create session
  # GET  /ggc/:code      the game session
  # POST /ggc/:code/*    session member actions
  get "/ggc", to: "game_sessions#new", as: :ggc
  resources :game_sessions, only: [:create, :show], param: :code, path: "ggc" do
    member do
      post :join
      post :join_group
      post :update_group_name
      post :start
      post :end_game
      post :submit_word
    end
  end
end
