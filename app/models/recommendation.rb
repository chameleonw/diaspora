class NotVisibleError < RuntimeError; end
class Recommendation < ActiveRecord::Base
  include Diaspora::Federated::Base
  include Diaspora::Guid
  #include Diaspora::Relayable

  #attr_accessible :author_id, :rating, :recipient_id, :user_handle

  xml_attr :created_at
  xml_reader :diaspora_handle # the senders handle I think
  xml_reader :recipient_handle # do we even need this?
  xml_attr :user_handle # the handle I want to recommend
  xml_attr :rating # the rating of the recommended handle


  belongs_to :recipient, :class_name => 'Person'
  belongs_to :author, :class_name => 'Person'


  def recipients
    [] << self.recipient
  end


# This is actually the sender's handle
  def diaspora_handle
    self.author.diaspora_handle
  end

  def diaspora_handle= nh
    self.author = Webfinger.new(nh).fetch
  end


# The recipients handle
  def recipient_handle
    self.recipient.diaspora_handle
  end
  
  def recipient_handle= handle
    self.recipient = Webfinger.new(handle).fetch
    
  end


  def subscribers(user)
    self.recipients
    #Person.where(id: 1)
  end

  def receive(user, person)
    logger.debug "-------------------------------------About to receive a recommendation-----------------------------------------"
    Recommendation.find_or_create_by_guid(self.attributes)
  end
 
  def public?
    false
  end

end
