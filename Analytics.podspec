Pod::Spec.new do |spec|
  spec.name         = "Analytics"
  spec.version      = "1.0.9"
  spec.summary      = "YuktaMedia Analytics sdk for iOS."
  spec.description  = <<-DESC
Analytics library is small light weight library which enable app developers to collect app usage analytics and send it to YuktaMedia, where app developers can see details in beautiful dashboard and can take action against any issues.
                   DESC

  spec.homepage     = "https://yuktamedia.com"
  spec.license      = { :type => "MIT" }


  spec.author             = { "Shrikant Patwari" => "shrikant.patwari@yuktamedia.com" }
  spec.social_media_url   = "https://twitter.com/PatwariShrikant"

  spec.ios.deployment_target = "7.0"
  spec.tvos.deployment_target = "9.0"

  spec.source       = { :git => "https://github.com/yuktamedia/Analytics.git", :tag => "#{spec.version}" }


  spec.source_files = [
    'Analytics/Classes/**/*',
    'Analytics/Internal/**/*'
  ]
end
