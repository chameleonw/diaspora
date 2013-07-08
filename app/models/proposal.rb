class NotVisibleError < RuntimeError; end
class Proposal < ActiveRecord::Base
  include Diaspora::Federated::Base
  include Diaspora::Guid



#class Proposal < ActiveRecord::Base
#  attr_accessible :guid, :handle, :rating, :recommendation_id
#end

  xml_attr :handle
  xml_attr :created_at
  xml_attr :rating
  xml_reader :conversation_guid

  belongs_to :recommendation, :touch => true

  def conversation_guid
    self.recommendation.guid
  end

  def conversation_guid= guid
    if rec = Recommendation.find_by_guid(guid)
      self.recommendation_id = rec.id
    end
  end


  def parent_class
    Recommendation
  end

  def parent
    self.recommendation
  end

  def parent= parent
    self.recommendation = parent
  end


  def subscribers(user)
    self.recommendation.recipients
  end

  def receive(user, person)
    logger.debug "-------------------------------------About to receive a proposal-----------------------------------------"
    Proposal.find_or_create_by_guid(self.attributes)
  end
 
  def public?
    false
  end
end
