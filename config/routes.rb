Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Home page - create new session
  root "home#index"

  # Game sessions
  resources :game_sessions, only: [:create, :show], param: :code do
    member do
      post :join
      post :start
      post :end_game
      post :submit_word
    end
  end
end
