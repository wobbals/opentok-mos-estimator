#OpenTok MOS - JS

## Usage

* Include `index.js` in your app controller.

* After creating a subscriber, initialize an MOS estimator: 
```js
var mosEstimator = SubscriberMOS(subscriber);
```

* At some point during the life of the subscriber, query for your scores:

```js
subscriber.on("destroyed", function() {
  console.log("Subscriber quality score: " + mosEstimator.qualityScore());
});
```
