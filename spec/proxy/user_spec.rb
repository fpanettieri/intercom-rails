require 'spec_helper'

describe IntercomRails::Proxy::User do
  ProxyUser = IntercomRails::Proxy::User

  DUMMY_USER = dummy_user(:email => 'ciaran@intercom.io', :name => 'Ciaran Lee')

  it 'raises error if no user found' do
    expect { ProxyUser.current_in_context(Object.new) }.to raise_error(IntercomRails::NoUserFoundError)
  end

  it 'finds current_user' do
    object_with_current_user_method = Object.new
    object_with_current_user_method.instance_eval do
      def current_user
        DUMMY_USER
      end
    end

    @user_proxy = ProxyUser.current_in_context(object_with_current_user_method)
    expect(@user_proxy.user).to eq(DUMMY_USER)
  end

  it 'finds user instance variable' do
    object_with_instance_variable = Object.new
    object_with_instance_variable.instance_eval do
      @user = DUMMY_USER
    end

    @user_proxy = ProxyUser.current_in_context(object_with_instance_variable)
    expect(@user_proxy.user).to eq(DUMMY_USER)
  end

  it 'finds config user' do
    object_from_config = Object.new
    object_from_config.instance_eval do
      def something_esoteric
        DUMMY_USER
      end
    end

    IntercomRails.config.user.current = Proc.new { something_esoteric }
    @user_proxy = ProxyUser.current_in_context(object_from_config)
    expect(@user_proxy.user).to eq(DUMMY_USER)
  end

  it 'raises error if config.user.current is set but does not resolve' do
    IntercomRails.config.user.current = Proc.new { something_esoteric }
    object_with_instance_variable = Object.new
    object_with_instance_variable.instance_eval do
      @user = DUMMY_USER
    end

    expect { ProxyUser.current_in_context(object_with_instance_variable) }.to raise_error(IntercomRails::NoUserFoundError)
  end

  it 'includes custom_data' do
    plan_dummy_user = DUMMY_USER.dup
    plan_dummy_user.instance_eval do
      def plan
        'pro'
      end
    end

    IntercomRails.config.user.custom_data = {
      'plan' => :plan
    }

    @user_proxy = ProxyUser.new(plan_dummy_user)
    expect(@user_proxy.to_hash['plan']).to eql('pro')
  end

  it 'converts dates to timestamps' do
    plan_dummy_user = DUMMY_USER.dup
    plan_dummy_user.instance_eval do
      def some_date
        Time.at(5)
      end
    end

    IntercomRails.config.user.custom_data = {
      'some_date' => :some_date
    }

    @user_proxy = ProxyUser.new(plan_dummy_user)
    expect(@user_proxy.to_hash['some_date']).to eq(5)
  end

  it 'is considered valid if user_id or email' do
    expect(ProxyUser.new(DUMMY_USER).valid?).to be(true)
  end

  it 'works with hashes' do
    user = {
      email: 'hash@foo.com'
    }
    expect(ProxyUser.new(user).valid?).to be(true)
  end

  it 'considers new records to be invalid' do
    new_record_user = dummy_user(:email => 'not-saved@intercom.io', :name => 'New Record')

    def new_record_user.new_record?
      true
    end

    expect(ProxyUser.new(new_record_user).valid?).to be(false)
  end

  it 'includes custom data from intercom custom data' do
    object_with_intercom_custom_data = Object.new
    object_with_intercom_custom_data.instance_eval do
      def intercom_custom_data
        Object.new.tap do |o|
          o.instance_eval do
            def user
              {:ponies => :rainbows}
            end
          end
        end
      end
    end

    @user_proxy = ProxyUser.new(DUMMY_USER, object_with_intercom_custom_data)
    expect(@user_proxy.to_hash[:ponies]).to eql(:rainbows)
  end

  it 'is invalid if whiny nil' do
    NilClass.class_eval do
      def id
        raise ArgumentError, "boo"
      end
    end

    search_object = nil
    expect(ProxyUser.new(search_object).valid?).to eq(false)
  end

  it 'gets/sets lead_attributes' do
    IntercomRails.config.user.lead_attributes = %w(utm_source ref_data)
    expect(IntercomRails.config.user.lead_attributes).to eq(["utm_source", "ref_data"])
  end

  it 'gets/sets lead_attributes with valid types' do
    expect { IntercomRails.config.user.lead_attributes = "utm_source" }.to raise_error(ArgumentError)
  end

  it 'includes avatar' do
    IntercomRails.config.user.avatar = {
      'type' => 'avatar',
      'image_url' => 'https://example.org/128Wash.jpg',
    }
    expect(IntercomRails.config.user.avatar.to_hash['type']).to eql('avatar')
    expect(IntercomRails.config.user.avatar.to_hash['image_url']).to eql('https://example.org/128Wash.jpg')
  end
end
