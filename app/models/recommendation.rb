
class NotVisibleError < RuntimeError; end
class Recommendation < ActiveRecord::Base
  include Diaspora::Federated::Base
  include Diaspora::Guid
  #include Diaspora::Relayable

  #attr_accessible :author_id, :rating, :recipient_id, :user_handle

  
#class Recommendation < ActiveRecord::Base
#  attr_accessible :author_id, :guid, :proposal_id, :recipient_id
#end

  xml_attr :created_at
  xml_reader :diaspora_handle # the senders handle I think
  xml_reader :recipient_handle # do we even need this?
  xml_attr :proposals, :as => [Proposal]

  has_many :proposals

  belongs_to :recipient, :class_name => 'Person'
  belongs_to :author, :class_name => 'Person'


  accepts_nested_attributes_for :proposals

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
    rec = Recommendation.find_or_create_by_guid(self.attributes)

    self.proposals.each do |proposal|
      proposal.conversation_id = cnv.id
      proposal.receive(user, person)
      #Notification.notify(user, received_proposal, person) if proposal.respond_to?(:notification_type)
    end

  end
 
  def public?
    false
  end

end