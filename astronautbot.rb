require 'twitter'
require 'time'
require 'json'
require 'yaml'
require 'logger'

logger = Logger.new("#{File.basename(__FILE__, ".rb")}.txt", 'weekly')

class TinyAstronautRunner
	LastTweetTimeFile = "last_response.dat";

	def initialize(logger, twitter_client)
		@logger = logger;
		@twitter_client = twitter_client;
		@prng = Random.new
		@last_response_time = get_last_response_time;
	end
	
	def get_last_response_time
		last_time = Time.new
		begin
			f = File.new(LastTweetTimeFile, "r")
			last_time = Time.parse(f.read)
			@logger.info("Last response read from file: #{last_time}");
			f.close
		rescue Exception => e
			@logger.warn("Problem reading file: #{e}");
		end
		
		last_time
	end

	def set_last_response_time last_time
		@last_response_time = last_time;
		f = File.new(LastTweetTimeFile, "w")
		f.write(last_time.to_s)
		f.close
	end
	
	def run
		while(true) do
			#anywhere from 3 to 4 hours between refreshes
			time_to_sleep = ((@prng.rand(1.0) + 3.0) * 60 * 60).floor;
			@logger.info("Sleeping for #{(time_to_sleep/60).round} minutes.");
			sleep(time_to_sleep)
			
			do_astronaut
		end
	end
	
	def do_astronaut
		@twitter_client.search("from:tiny_star_field", :result_type => "recent").take(1).each{ |tweet|
			@logger.info("Got tweet: #{tweet.id}, #{tweet.created_at}");
			time = tweet.created_at
			if (time > @last_response_time) then
				do_starfield(tweet)
			end
		}
	end
	
	def get_astronaut
		rocket = [0x1F680].pack("U");
		
		laika = [0x1F436].pack("U");
		spacecat = [0x1F408].pack("U");
		space_police = [0x1F694].pack("U");
		space_car = [0x1F698].pack("U");
		astronauts = [laika, spacecat, space_police, space_car];
		
		if(@prng.rand(1.0) > 0.9) then
			return astronauts.sample;
		end
		
		return rocket;
	end
	
	def do_starfield(tweet)
		original_content = tweet.text;
		
		tries = 0;
		found = false;
		chararray = original_content.each_char.to_a;
		count = chararray.length;
		random_index = 0;
		while(tries < 100 && !found) do
			random_index = @prng.rand(count).floor
			if(chararray[random_index] == " ") then
				chararray[random_index] = get_astronaut;
				found = true;
			end
			tries += 1;
		end
		
		if(!found) then
			@logger.warn("Oh no, didn't find a space for the astronaut! :(");
			return;
		end
		
		@logger.info("Found a spot for our astronaut at #{random_index}, after #{tries} iterations.");
		at_reply = "\n@tiny_star_field";
		num_to_chop = (chararray.length + at_reply.length) - 140;
		if(num_to_chop > 0) then
			chararray = chararray[0...-num_to_chop];
		end
		new_content = chararray.join("") + at_reply;
		
		@logger.info("Tweeting: \n#{new_content}");
		@twitter_client.update(new_content, :in_reply_to_status_id => tweet.id);
		
		set_last_response_time tweet.created_at
	end
end

twitter_config = YAML.load_file('config.yml')

twitter_client = Twitter::REST::Client.new do |config|
  config.consumer_key = twitter_config["consumer_key"]
  config.consumer_secret = twitter_config["consumer_secret"]
  config.access_token = twitter_config["access_token"]
  config.access_token_secret = twitter_config["access_token_secret"]
end

runner = TinyAstronautRunner.new(logger, twitter_client);
begin
	runner.run
rescue Exception => e
	logger.error("Exception while running! #{e} #{e.backtrace}");
end