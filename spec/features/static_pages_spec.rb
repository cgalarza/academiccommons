require 'rails_helper'

RSpec.describe 'static pages', type: :feature do
  context 'about' do
    it 'render about page' do
      visit 'about'
      expect(page).to have_content 'Columbia University Libraries'
    end
  end
end
