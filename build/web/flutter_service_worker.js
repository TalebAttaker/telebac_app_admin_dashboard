'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"_headers": "64872fe0154e6e33663bc90fa1859306",
"version.json": "5a03a17fbe23db4ec6d96326a50205ce",
"assets/AssetManifest.bin": "d4dbec51ae06d29bb99e3ed2d5dcc293",
"assets/assets/images/telebac_logo.svg": "982754cc5c19af6da461cc57cec8bc2c",
"assets/assets/images/logo.png": "1eddbdf7226237f87dfbd717091c98ed",
"assets/assets/lottie/loading_spinner.json": "4802a81baa0498bd960df7c0919741d6",
"assets/assets/lottie/success_check.json": "d851f164c5de374640f572ce6812a6d0",
"assets/assets/lottie/student_studying.json": "9e2cf4d247b8dcbef8a025b3a88f8e80",
"assets/assets/lottie/empty_box.json": "10e76aff1e85f1261d11226e72aed01b",
"assets/assets/lottie/loading_dots.json": "fbf8da3d6b7b1ec42c001d1257455310",
"assets/assets/lottie/splash_education.json": "fbf8da3d6b7b1ec42c001d1257455310",
"assets/assets/lottie/loading_book.json": "0640c7528a4a04f7b0b8f8762920d3ab",
"assets/assets/lottie/empty_data.json": "757e7af7ec78258c82dcd57081a51e29",
"assets/assets/lottie/loading_simple.json": "9441556c8765b7496d0b2748ee2f3df8",
"assets/assets/lottie/error_cross.json": "2c4bd762831a20cb7b3e318265fe4988",
"assets/assets/lottie/error_warning.json": "14adc48a53b3b19886b88dabc2b539ae",
"assets/assets/lottie/books_study.json": "7eed0f68676c339fe175a5c357c17682",
"assets/assets/lottie/online_learning.json": "668111cf8d0ee1bb421b66827b8f9089",
"assets/assets/lottie/idea.json": "808b903200f16a3c3f7064304840af2d",
"assets/assets/lottie/no_internet.json": "ec913b9be9ee9c09e36e1595b9c9137c",
"assets/assets/lottie/video_play.json": "32fecc717acd6b9d8dc178051b187d64",
"assets/assets/lottie/journey.json": "d7496987ca397f8318df81b2738d7731",
"assets/assets/lottie/success_celebration.json": "e1bb1741df24cd6b3433f4081d09c2f9",
"assets/assets/lottie/live_session.json": "487f575a4a4a0ecd2c8d70c515661084",
"assets/assets/lottie/search.json": "f6ef0fa67c7c6b45fe53a3575e465b53",
"assets/assets/lottie/success_simple.json": "1f0d15e6fd9e07ca09fb051d22c6ae8d",
"assets/assets/lottie/empty_list.json": "7df81934889a05e3e53aa66e58c5a6cf",
"assets/assets/lottie/welcome.json": "12657f4822dc91de1c5d49ee01e2d6d3",
"assets/assets/lottie/success_done.json": "3986c6bbbb3c88dec60b3d5fa568af0a",
"assets/assets/lottie/graduation.json": "912fec5a2becdfb387e6e602b1794707",
"assets/assets/lottie/live_stream.json": "394d854f65b98f9f241b860ebb645539",
"assets/assets/lottie/empty_search.json": "6126b7a227c0ace68510d982fa69953f",
"assets/assets/lottie/play_button_loading.json": "641455b0d00902e03ee21c6abad7c829",
"assets/assets/lottie/error_simple.json": "0306cb9c22346d7e5076e34f6839f7cf",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "87c8411e3f97c27b9a49cdcb2c270141",
"assets/NOTICES": "cbf5f71fa1529e324cc0bc1bbbea11da",
"assets/packages/wakelock_plus/assets/no_sleep.js": "7748a45cd593f33280669b29c2c8919a",
"assets/packages/flutter_image_compress_web/assets/pica.min.js": "6208ed6419908c4b04382adc8a3053a2",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/AssetManifest.bin.json": "38a3e3b20ed050a384f0e67caa1ed2d2",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"index_admin.html": "cc54d7f9bbd993a73f998f64756d9ab9",
"main.dart.js": "957b6b8f04b690bc4ad1d48f888693ea",
"icons/Icon-512.png": "1eddbdf7226237f87dfbd717091c98ed",
"icons/Icon-maskable-192.png": "9998f7cf528b13931823dda879a9e71d",
"icons/Icon-192.png": "9998f7cf528b13931823dda879a9e71d",
"icons/Icon-maskable-512.png": "1eddbdf7226237f87dfbd717091c98ed",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"index.html": "0008956d95b6048d8670963a4694827f",
"/": "0008956d95b6048d8670963a4694827f",
"flutter_bootstrap.js": "e1b78e4a2d42637031fb4c64217d77e2",
"favicon.png": "9222d4864eb5b0e7f850ea1a4cfa954a",
"manifest.json": "2c846e12caede2de982a83a303c22759"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
