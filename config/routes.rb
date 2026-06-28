Rails.application.routes.draw do
  get  'gantt_holiday_settings', to: 'gantt_holiday_settings#index'
  post 'gantt_holiday_settings/update', to: 'gantt_holiday_settings#update'
  post 'gantt_holiday_settings/import_csv', to: 'gantt_holiday_settings#import_csv'
  put 'projects/:project_id/gantt_holiday', to: 'gantt_holiday_projects#update', as: 'project_gantt_holiday'
  post 'oyakodon/bulk_assign', to: 'oyakodon#bulk_assign'
  post 'oyakodon/release/:id', to: 'oyakodon#release', as: 'oyakodon_release'
end