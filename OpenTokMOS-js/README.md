#OpenTok MOS - JS

## Usage

* Include `OpenTokMOS.js` in your app controller:
```js
<script src='/OpenTokMOS.js' charset="utf-8"></script>
```

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
