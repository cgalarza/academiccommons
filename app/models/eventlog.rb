class Eventlog < ActiveRecord::Base
   
    attr_accessible :id, :event_name, :uid, :ip, :session_id, :timestamp
    has_many :logvalues

end