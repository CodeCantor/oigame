class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable, :omniauthable, :async

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me, :mailing, :name, :vat, :provider, :uid
  attr_accessible :email, :password, :password_confirmation, :remember_me, :mailing, :name, :vat, :provider, :uid, :roles, as: :admin

  has_many :campaigns, :dependent => :destroy
  has_and_belongs_to_many :sub_oigames
  has_many :donations

  after_create :set_role

  USER_ROLES = %w[user editor admin]
  
  class << self

    def get_mailing_users
      where('mailing = ?', true).all
    end

    def recent(limit = nil)
      order('created_at DESC').limit(limit)
    end

    def find_for_facebook_oauth(auth, signed_in_resource=nil)
      user = self.where(:provider => auth.provider, :uid => auth.uid).first || self.where(:email => auth.info.email).first
      unless user
        user = User.new
        user.name = auth.extra.raw_info.name
        user.provider = auth.provider
        user.uid = auth.uid
        user.email = auth.info.email
        user.password = Devise.friendly_token[0,20]
        user.confirmed_at = DateTime.now
        user.skip_confirmation!
        user.save
      end
      user
    end

    def find_for_twitter_oauth(auth, signed_in_resource=nil)
      user = self.where(:provider => auth["provider"], :uid => auth["uid"]).first
      unless user
        user = User.new
        user.name = auth["info"]["name"]
        user.provider = auth["provider"]
        user.uid = auth["uid"]
        user.email = nil
        user.password = Devise.friendly_token[0,20]
        user.confirmed_at = DateTime.now
        user.skip_confirmation!
      end
      user
    end

    def new_with_session(params, session)
      super.tap do |user|
        if data = session["devise.facebook_data"] && session["devise.facebook_data"]["extra"]["raw_info"]
          user.email = data["email"] if user.email.blank?
        end
      end
    end
  end
  
  #def role=(roles)
  #  roles=(roles)
  #end

  #def role
  #  roles
  #end

  def roles=(roles)
    self.roles_mask = (roles & USER_ROLES).map { |r| 2**USER_ROLES.index(r) }.inject(0, :+)
  end
  
  def roles
    USER_ROLES.reject do |r|
      ((roles_mask || 0) & 2**USER_ROLES.index(r)).zero?
    end
  end

  def is?(role)
    roles.include?(role.to_s)
  end

  def ready_for_donation
    name.blank? ? false : true
  end
  
  def ready_for_add_credit
    name.blank? ? false : true
  end

  def user?
    self.roles.include? == 'user'
  end

  def editor?
    self.roles.include? == 'editor'
  end

  def admin?
    self.roles.include? == 'admin'
  end

  # para declarative_auth
  def role_symbols
    roles.map do |role|
      role.underscore.to_sym
    end
  end

  protected

  def set_role
    self.roles = ['user']
    self.save
  end
end
