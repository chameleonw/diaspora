module RecommendationsHelper
  def contact_persons
    current_user.contacts.map do |contact|
      contact.person.id
    end
  end
end