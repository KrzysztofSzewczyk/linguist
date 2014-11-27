module Linguist
  module Strategy
    # Detect language using the bayesian classifier
    class Classifier
      def self.call(blob, languages)
        Linguist::Classifier.classify(Samples.cache, blob.data, languages.map(&:name)).map do |name, _|
          # Return the actual Language object based of the string language name (i.e., first element of `#classify`)
          Language[name]
        end
      end
    end
  end
end
