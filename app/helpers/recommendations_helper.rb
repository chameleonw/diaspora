module RecommendationsHelper

  def contact_persons
    current_user.contacts.map do |contact|
      contact.person.id
    end
  end

  def compute_from_received
    proposals = RecommendationAlgorithm.new(current_user).compute_from_received
    proposals.map { |proposal_arr| proposal_arr[0] } 
             .select { |person| current_user.contacts.map { |contact| contact.person }.exclude? person } unless proposals.nil?

  end

  def prioritized_friend_list
    RecommendationAlgorithm.new(current_user).prioritized_friend_list
  end

  def send_recommendations_for_first
    RecommendationAlgorithm.new(current_user).send_recommendations_for(current_user.contacts.first.person)
  end
end