module Carto
  class EncryptionService

    AUTH_TOKEN_DIGEST_KEY = '6da98b2da1b38c5ada2547ad2c3268caa1eb58dc20c9144ead844a2eda1917067a06dcb54833ba2'.freeze

    DEFAULT_AUTH_DIGEST_KEYS = {
      Digest::SHA1 => '47f940ec20a0993b5e9e4310461cc8a6a7fb84e3',
      Digest::SHA256 => '1211b3e77138f6e1724721f1ab740c9c70e66ba6fec5e989bb6640c4541ed15d06dbd5fdcbd3052b'
    }.freeze

    DEFAULT_SHA_CLASS = Digest::SHA1

    def encrypt(password:, sha_class: nil, salt: nil, secret: nil)
      return argon2_encrypt(password, secret) unless sha_class
      sha_digest(sha_class: sha_class, args: [salt, password])
    end

    def verify(password:, secure_password:, salt: nil, secret: nil)
      return argon2_verify(password, secure_password, secret) if argon2?(secure_password)
      verify_sha(password, secure_password, salt)
    end

    def make_token(sha_class: DEFAULT_SHA_CLASS, digest_key: nil)
      initial_digest = [Time.now, (1..10).map { rand.to_s }]
      sha_digest(sha_class: sha_class, initial_digest: initial_digest, digest_key: digest_key)
    end

    def argon2?(encryption)
      encryption =~ /^\h{194}$/
    end

    private

    def argon2_encrypt(password, secret)
      argon2 = Argon2::Password.new(secret: secret)
      argon_hash = argon2.create(password)
      encode_to_hex(argon_hash)
    end

    def argon2_verify(password, secure_password, secret)
      argon2_hash = decode_hex(secure_password)
      Argon2::Password.verify_password(password, argon2_hash, secret)
    end

    def encode_to_hex(string)
      string.unpack('H*').first
    end

    def decode_hex(hex_string)
      hex_string.scan(/../).map(&:hex).pack('c*')
    end

    def verify_sha(password, secure_password, salt)
      case secure_password
      when /^\h{40}$/ then secure_password == sha_digest(sha_class: Digest::SHA1, args: [salt, password])
      when /^\h{64}$/ then secure_password == sha_digest(sha_class: Digest::SHA256, args: [salt, password])
      else false
      end
    end

    def sha_digest(sha_class: DEFAULT_SHA_CLASS, initial_digest: nil, digest_key: nil, args: [])
      digest_key ||= DEFAULT_AUTH_DIGEST_KEYS[sha_class]
      digest = initial_digest || digest_key
      args_join = '--' if sha_class == Digest::SHA1

      10.times do
        joined_args = [digest, args, digest_key].flatten.join(args_join)
        digest = sha_class.hexdigest(joined_args)
      end
      digest
    end

  end
end
