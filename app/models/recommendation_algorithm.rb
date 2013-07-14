class RecommendationAlgorithm

  attr_accessor :current_user, :prioritized_friend_list, :all_interactions

  def initialize(user)
    @current_user = user
    get_all_interactions
    @prioritized_friend_list = prioritize_friend_list!
  end      

  #------------------------------------------------------------------------------------------------------------------------
  # Returns a list of persons who are mutual friends of the current user
  # The list is sorted descendingly with the highest person rating on top
  def prioritize_friend_list!

    # Preparing the initial data
    priority_array = Array.new
    mutual_contact_persons(@current_user).each do |person|
      priority_array.push( { :person => person,
    		                 :interactions => interaction_count(person),
    		                 :mutual_friend_count => mutual_friend_count(@current_user, person),
    		                 :shared_tag_count => shared_tag_count(@current_user.person, person) } )
    end
    
    # Computing reference data
    highest_interaction = priority_array.sort_by { |k| -k[:interactions] }.first[:interactions]
    highest_mutual_friends_count = priority_array.sort_by { |k| -k[:mutual_friend_count] }.first[:mutual_friend_count]
    highest_shared_tag_count = priority_array.sort_by { |k| -k[:shared_tag_count] }.first[:shared_tag_count]

    # Computing individual rankings
	priority_array.each do |hash|
	  hash[:interaction_rating] = hash[:interactions].to_f / (highest_interaction == 0 ? 1 : highest_interaction)
	  hash[:mutual_friend_rating] = hash[:mutual_friend_count].to_f / (highest_mutual_friends_count == 0 ? 1 : highest_mutual_friends_count)
	  hash[:shared_tag_rating] = hash[:shared_tag_count].to_f / (highest_shared_tag_count == 0 ? 1 : highest_shared_tag_count)

	  # computing the final priority rating TODO: remove magic numbers
	  hash[:rating] = 0.5 * hash[:interaction_rating] + 0.3 * hash[:mutual_friend_rating] + 0.2 * hash[:shared_tag_rating]
	end

	priority_array.sort_by { |k| -k[:rating] }
  end

  # should compute and send recommendations to a specified contact - make sure it's a contact!!!!
  def send_recommendations_for(referral)
  	recommendation_array = Array.new
  	possible_contacts = mutual_contact_persons(@current_user) - mutual_contact_persons(referral)
    possible_contacts.each do |person|
      recommendation_array.push( { :person => person,
    		                 :combined_interaction => interaction_count(person) + interaction_count(referral),
    		                 :path_count => 1,
    		                 :shared_tag_count => shared_tag_count(person, referral) } )
    end

    # Computing reference data
    highest_combined_interaction = recommendation_array.sort_by { |k| -k[:combined_interaction] }.first[:combined_interaction]
    highest_path_count = recommendation_array.sort_by { |k| -k[:path_count] }.first[:path_count]
    highest_shared_tag_count = recommendation_array.sort_by { |k| -k[:shared_tag_count] }.first[:shared_tag_count]


    # Computing individual rankings
	recommendation_array.each do |hash|
	  hash[:interaction_rating] = hash[:combined_interaction].to_f / (highest_combined_interaction == 0 ? 1 : highest_combined_interaction)
	  hash[:path_count_rating] = hash[:path_count].to_f / (highest_path_count == 0 ? 1 : highest_path_count)
	  hash[:shared_tag_rating] = hash[:shared_tag_count].to_f / (highest_shared_tag_count == 0 ? 1 : highest_shared_tag_count)

	  # computing the final priority rating TODO: remove magic numbers
	  hash[:rating] = 0.25 * hash[:interaction_rating] + 0.35 * hash[:path_count] + 0.4 * hash[:shared_tag_rating]
	end
	recommendation_array.sort_by { |k| -k[:rating] }

    recommendation = Recommendation.new(author_id: @current_user.person.id, recipient_id: referral.id)
    recommendation_array.first(3).each do |ext_person_hash|
    	recommendation.proposals.build(handle: ext_person_hash[:person].diaspora_handle, rating: ext_person_hash[:rating])
    end

    if recommendation.save
      Postzord::Dispatcher.build(@current_user, recommendation).post
    end
  end

  # should compute the resulting recommendations based on received ratings and friend priorities
  def compute_from_received
  	result = Array.new()
  	my_recommendations = Recommendation.where(recipient_id: @current_user.person.id)
  	unless my_recommendations.empty?
      my_recommendations.each do |recommendation|
      	recommendation.proposals.each do |proposal|
          proposal_person = proposal.person
          recommender = @prioritized_friend_list.detect {|f| f[:person].id == recommendation.author_id }

          # received handle could not be converted to a person? or recommender is not our friend?
          unless (proposal_person.nil? || recommender.nil?)
            result.push({:person => proposal_person,
                         :rating => proposal.rating * recommender[:rating] }) 
          end
        end
      end
    end
    result.each_with_object(Hash.new(0)) { |o, h| h[o[:person]] += o[:rating] }.sort_by{|k,v| -v}
  end
  #------------------------------------------------------------------------------------------------------------------------

  # returns a list of persons
  def mutual_contact_persons(person)
    person.contacts.select { |contact| contact.mutual? }.map { |contact| contact.person }
  end

  # computes the number of mutual friends of the current_user with the specified person
  def mutual_friend_count(person1, person2)
  	(mutual_contact_persons(person1) & mutual_contact_persons(person2)).size
  end

  # computes the number of shared tags of the current_user with the specified person
  def shared_tag_count(person1, person2)
  	( person1.profile.tag_string.split(" ") & person2.profile.tag_string.split(" ") ).size
  end


  # computes the number of interactions of the current_user with the specified person
  def interaction_count(person)
  	@all_interactions[person] unless !@all_interactions
  end
  
  def get_all_interactions
    @all_interactions = author_occurance_current_user_mentionned_by
      .merge(author_occurance_current_users_mentions) {|key,val1,val2| val1+val2}
        .merge(author_occurance_current_user_liked_on
      	  .merge(author_occurance_current_users_likes) {|key,val1,val2| val1+val2}
      	    .merge(author_occurance_current_user_commented_on
      	      .merge(author_comment_occurance_on_current_users_posts) {|key,val1,val2| val1+val2}) {|key,val1,val2| val1+val2}) {|key,val1,val2| val1+val2}
  end

  

  #----------------------------------------------------------
  # interaction partial functions
  #----------------------------------------------------------

  # very ugly, using map would be nicer i supppose
  # returns a hash of authors and occurance #current_user commenting a post of s.o
  def author_occurance_current_user_commented_on
    author_list = []
    @current_user.person.comments.each do |comment|
      author_list << comment.commentable.author
    end
    author_list.each_with_object(Hash.new(0)) { |o, h| h[o] += 1 }
  end
    
  # very ugly, using map would be nicer i supppose
  # returns a hash of authors and occurance #s.o commenting on a post of the current_user
  def author_comment_occurance_on_current_users_posts
    author_list = []
    @current_user.person.posts.each do |post|
      post.comments.each do |comment|
        author_list << comment.author
      end
    end
    author_list.each_with_object(Hash.new(0)) { |o, h| h[o] += 1 }
  end
    
  #likes of s.o on current_user post
  #returns a hash of authors and occurance
  def author_occurance_current_users_likes
    author_list = []
    @current_user.person.posts.each do |like|
      like.likes.each do |point|
        author_list << point.author
      end 
    end
    author_list.each_with_object(Hash.new(0)) { |o, h| h[o] += 1 }
  end
    
  # like of the current_user on s.o else post
  # returns a hash of authors and occurance
  def author_occurance_current_user_liked_on
    author_list = []
    @current_user.person.likes.each do |like|
       author_list << like.target.author
    end
    author_list.each_with_object(Hash.new(0)) { |o, h| h[o] += 1 }
  end

  # mentions of s.o by the current_user
  # returns a hash of authors and occurance
  def author_occurance_current_users_mentions
    author_list = []
    @current_user.person.posts.each do |mention|
      mention.mentions.each do |point|
        author_list << point.person
      end
    end
    author_list.each_with_object(Hash.new(0)) { |o, h| h[o] += 1 }
  end

  # mentions of the current_user by s.o
  # returns a hash of authors and occurance
  
  def author_occurance_current_user_mentionned_by
    author_list = []
    current_user.person.mentions.each do |mention|
      author_list << mention.post.author
    end
    author_list.each_with_object(Hash.new(0)) { |o, h| h[o] += 1 }
  end

end