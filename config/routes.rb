Rails.application.routes.draw do
  resources :users do
    resources :bookmarks
  end
  resources :bookmarks
  resources :tags
end
