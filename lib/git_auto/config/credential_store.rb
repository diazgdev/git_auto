# frozen_string_literal: true

require "openssl"
require "base64"
require "fileutils"
require "yaml"

module GitAuto
  module Config
    class CredentialStore
      CREDENTIALS_FILE = File.join(File.expand_path("~/.git_auto"), "credentials.yml")
      ENCRYPTION_KEY = ENV["GIT_AUTO_SECRET"] || "default_development_key"

      def initialize
        ensure_credentials_file
      end

      def store_api_key(key, provider)
        credentials = load_credentials
        credentials[provider.to_s] = encrypt(key)
        save_credentials(credentials)
      end

      def get_api_key(provider)
        credentials = load_credentials
        encrypted_key = credentials[provider.to_s]
        return nil unless encrypted_key

        decrypt(encrypted_key)
      end

      def api_key_exists?(provider)
        credentials = load_credentials
        credentials.key?(provider.to_s)
      end

      private

      def ensure_credentials_file
        dir = File.dirname(CREDENTIALS_FILE)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
        FileUtils.touch(CREDENTIALS_FILE) unless File.exist?(CREDENTIALS_FILE)
      end

      def load_credentials
        content = File.read(CREDENTIALS_FILE).strip
        content.empty? ? {} : YAML.safe_load(content)
      end

      def save_credentials(credentials)
        File.write(CREDENTIALS_FILE, YAML.dump(credentials))
      end

      def encrypt(text)
        cipher = OpenSSL::Cipher.new("aes-256-cbc")
        cipher.encrypt
        cipher.key = Digest::SHA256.digest(ENCRYPTION_KEY)
        iv = cipher.random_iv
        encrypted = cipher.update(text) + cipher.final
        Base64.strict_encode64(iv + encrypted)
      end

      def decrypt(encrypted_data)
        encrypted = Base64.strict_decode64(encrypted_data)
        decipher = OpenSSL::Cipher.new("aes-256-cbc")
        decipher.decrypt
        decipher.key = Digest::SHA256.digest(ENCRYPTION_KEY)
        decipher.iv = encrypted[0..15]
        decipher.update(encrypted[16..]) + decipher.final
      end
    end
  end
end
