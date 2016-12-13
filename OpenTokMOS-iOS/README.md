# OpenTokMOS

## Example

To run the example project, clone the repo, and run `pod install` from the 
Example directory first.

## Usage

Wherever an `OTSubscriber` instance would be used, import the header from this
pod and use the `OTSubscriberMOS` subclass. Scores begin gathering as soon as
data is available, and can be retrieved at will. It is assumed to only be
necessary to gather a score at the end of the life of the subscriber, but scores
should be valid any time after the first stats gathering interval.

## Installation

OpenTokMOS is available through [CocoaPods](http://cocoapods.org), *in a private
specs repository*. To install it, simply add the following line to your Podfile:

```ruby
source 'https://github.com/wobbals/Specs.git'
pod "OpenTokMOS"
```

## Author

Charley Robinson, charley@tokbox.com

## License

OpenTokMOS is available under the Apache 2.0 license. 
See the LICENSE file for more info.
