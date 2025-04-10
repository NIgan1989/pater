// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/**
 * This script is executed as soon as Flutter Web (formerly known as FWIP) is launched.
 * It is responsible for interpreting incoming URL parameters to correctly initialize
 * Flutter Web regardless of the environtment it is loaded in.
 *
 * The most important feature this provides is hot-restart support for local development
 * workflows.
 */
(function() {
  // This script should only be included in the Flutter Web entrypoint (index.html).
  if (document.currentScript == null) {
    console.error('This script must be executed from an HTML <script> tag, or a JS module with document.currentScript present');
    return;
  }

  /**
   * Handles the creation of a TrustedTypes policy, if the feature is available.
   * @param {string} name 
   * @param {TrustedTypePolicyOptions} policy 
   * @returns {TrustedTypePolicy|null}
   */
  function createTrustedTypesPolicy(name, policy) {
    try {
      if (window.trustedTypes) {
        return trustedTypes.createPolicy(name, policy);
      }
    } catch (e) {
      console.warn(`Failed to create Trusted Types policy: ${e}`);
    }
    return null;
  }

  const flutterTTPolicy = createTrustedTypesPolicy('flutter-js', {
      createScriptURL: (url) => url,
  });

  // Override console.error if configured to auto reload.
  const buildMode = new URLSearchParams(window.location.search).get('flutter-build-mode');
  // Some tools serve the static files and expect console.error to reload for hot restart.
  const overrideError = "true" === localStorage.getItem("FlutterDevToolsOverrideConsoleMethods");

  // Known methods that trigger Flutter hot restart/hot reload.
  const hotReloadMethods = [
    "ResidentRunner.restartApp",
    "ResidentRunner.reassembleApplication",
  ];

  if (buildMode === "debug" || overrideError) {
    const originalConsoleError = console.error;
    console.error = function(...args) {
      const args_string = JSON.stringify(args).toLowerCase();
      if (hotReloadMethods.some(method => args_string.includes(method.toLowerCase()))) {
        console.info("Performing hot restart for debugging.");
        window.onbeforeunload = null;
        location.reload();
        // Return early. Don't log the unhandled exception, just trigger a hot restart.
        return;
      }
      return originalConsoleError.apply(console, args);
    };
  }

  /**
   * Maps a function from a URL into a SWC property name.
   * @param {*} sourceUrl 
   * @returns 
   */
  function getStoredCallback(sourceUrl) {
    return '__flutter_' + sourceUrl.replace(/[^a-zA-Z0-9_]/g, '_');
  }

  /**
   * Defines a property on the window to store a callback passed from ObjectiveC/Java.
   * @param {string} sourceUrl 
   * @param {function} callback 
   */
  function storeCallbackBySourceUrl(sourceUrl, callback) {
    const propName = getStoredCallback(sourceUrl);
    window[propName] = callback;
  }

  /**
   * Gets a callback related to the sourceUrl from the window object, if exists.
   * @param {string} sourceUrl 
   * @returns A callback, or undefined if not set.
   */
  function getCallbackBySourceUrl(sourceUrl) {
    const propName = getStoredCallback(sourceUrl);
    return window[propName];
  }

  const activePromises = new Map();

  /**
   * Resolves a script load promise with the given sourceURL.
   * @param {string} sourceUrl 
   * @param {any} value 
   */
  function resolveScriptLoadPromise(sourceUrl, value) {
    const callbacks = activePromises.get(sourceUrl) || [];
    for (let callback of callbacks) {
      callback.resolve(value);
    }
    if (callbacks.length > 0) {
      activePromises.delete(sourceUrl);
    }
  }

  /**
   * Rejects a script load promise with the given sourceURL.
   * @param {string} sourceUrl 
   * @param {object} error
   */
  function rejectScriptLoadPromise(sourceUrl, error) {
    const callbacks = activePromises.get(sourceUrl) || [];
    for (let callback of callbacks) {
      callback.reject(error);
    }
    if (callbacks.length > 0) {
      activePromises.delete(sourceUrl);
    }
  }

  /**
   * Creates a script tag.
   * @param {string} url 
   * @param {string|undefined} type
   * @returns {Promise<HTMLScriptElement>}
   */
  function injectScriptWithType(url, type) {
    if (getCallbackBySourceUrl(url) !== undefined) {
      return Promise.resolve(getCallbackBySourceUrl(url));
    }

    // See if we already have a promise for this sourceUrl.
    const existingPromises = activePromises.get(url);
    let promiseCbs = undefined;
    
    const scriptPromise = new Promise((resolve, reject) => {
      promiseCbs = { resolve, reject };
      // Cache the callbacks.
      if (existingPromises) {
        existingPromises.push(promiseCbs);
      } else {
        activePromises.set(url, [promiseCbs]);
      }
    });

    if (existingPromises) {
      // If there was already a script tag created for this URL, just use the existing
      // Promise to avoid making duplicate requests.
      return scriptPromise;
    }

    const parsedUrl = new URL(url, window.location.href);
    const script = document.createElement('script');
    script.src = flutterTTPolicy ? flutterTTPolicy.createScriptURL(parsedUrl.toString()) : parsedUrl.toString();
    if (type) {
      script.type = type;
    }

    script.addEventListener('load', () => {
      resolveScriptLoadPromise(url, getCallbackBySourceUrl(url) || scriptPromise);
    });

    script.addEventListener('error', (e) => {
      rejectScriptLoadPromise(url, e);
    });

    document.body.append(script);

    return scriptPromise;
  }

  /**
   * Creates a script tag of type=module.
   * @param {string} url 
   * @returns {Promise<function>}
   */
  function injectModuleScript(url) {
    return injectScriptWithType(url, 'module');
  }
  
  /**
   * Creates a script tag of type=application/javascript.
   * @param {string} url 
   * @returns {Promise<function>}
   */
  function injectScript(url) {
    return injectScriptWithType(url, undefined);
  }

  const scriptElement = document.currentScript;
  const entrypointUrl = new URL("./main.dart.js", scriptElement.src).toString();

  function engineInitializer() {
    return {
      /**
       * Initialize and run the Flutter app.
       * @param {*} config 
       * @returns A Promise that resolves to the Flutter app's (webOnlyMainEntrypoint || main) function.
       */
      async initializeEngine(config = {}) {
        // defaultConfig values
        config = {
          renderer: 'html',
          assetBase: scriptElement.getAttribute('src').replace('flutter.js', ''),
          useColorEmoji: false,
          canvasKitBaseUrl: undefined,
          canvasKitVariant: undefined,
          canvasKitVersion: undefined,
          profiling: false,
          ignoreDevicePixelRatio: false,
          serviceWorker: {
            serviceWorkerVersion: null,
          },
          ...config,
        };
  
        // Set Flutter Web entrypoint parameters
        window.flutterConfiguration = config;
  
        // Import entrypoint.
        if (config.renderer == 'canvaskit') {
          const { CanvasKitInit } = await import('./canvaskit.js');
          const { seedEntropy } = await import('./flutter_bootstrap.js');
  
          const canvasKitBase = config.canvasKitBaseUrl;
  
          const canvasKitVariant = config.canvasKitVariant;
  
          const canvasKitVersion = config.canvasKitVersion;
          // These defaults should be kept in sync with flutter_tools/lib/src/web/compile.dart.
          const canvasKitBaseUrl = canvasKitBase != null
            ? canvasKitBase
            : config.assetBase + 'canvaskit/';
  
          const canvasKitVariantStr = canvasKitVariant != null
            ? canvasKitVariant
            : 'auto';
  
          const canvasKitVersionStr = canvasKitVersion != null
            ? canvasKitVersion
            : 'latest';
  
          await CanvasKitInit({
            locateFile: (file) => {
              // Add v? to enable canvaskit versions. Default = canvaskit/
              // Add variant? to enable canvaskit variants. Default = auto
              let path = canvasKitBaseUrl + file;
              if (canvasKitVersionStr !== 'latest') {
                path = path.replace(new RegExp('\\.js$', 'g'), `.${canvasKitVersionStr}.js`);
              }
              return path;
            },
            useColorEmoji: config.useColorEmoji,
            variant: canvasKitVariantStr
          });
          // The `window.flutterCanvasKit` is now either auto/profiling/auto_and_profiling
          seedEntropy();
        }

        try {
          const appRunner = await injectScript(entrypointUrl);
          return appRunner;
        } catch (e) {
          console.error(`Failed to inject ${entrypointUrl}`, e);
          throw e;
        }
      },
  
      /**
       * This function can be used to run unit tests for Flutter app.
       * 
       * It is the caller's responsibility to properly setup the test environment
       * (i.e. provide polyfills for objects that are not available in the test
       * environment, etc).
       * 
       * @param {function} testRunner - A function that runs the tests.
       * @returns A Promise that resolves when the test runner completes.
       */
      async runApp(testRunner = null) {
        // The run function is provided by the Flutter app's main.dart.js
        // (the webOnlyMain entrypoint).
        const runEntrypoint = window._flutter_entry_point ? window._flutter_entry_point : window.main;
  
        if (testRunner) {
          // Run the tests
          return testRunner(runEntrypoint);
        } else {
          // Run the app
          return runEntrypoint();
        }
      }
    };
  }

  /* Starting from here, script execution differs based on how it is loaded. */

  // This function forces the script to load in an async fashion.
  // Note 1: this is required for the Web SDK to support the right execution order of JS.
  // Note 2: this function returns a promise for the loaded exports, because they are now async.
  function asyncLoad() {
    return new Promise((resolve, reject) => {
      // handle both UMD and ES Module loaders.
      // Use timeout to ensure this promise resolves asynchronously.
      // That's required to ensure the execution order of JS.
      // We want to return the public API for the ES Module, but for the UMD
      // module, we'll be returning module.exports.
      setTimeout(() => {
        // Module loaded successfully. Resolve the promise with the module exports.
        resolve(engineInitializer());
      }, 0);
    });
  }

  /**
   * Creates the `_flutter` namespace, and sets up `loader` API for the Flutter SDK.
   */
  function loadUMD() {
    // Create the namespace if it's not created already.
    // This supports loading the script async, defer, or with injection apis.
    window._flutter || (window._flutter = {});

    const loader = {
      /**
       * Loads the Flutter Web app with the specified config.
       * @param {*} config 
       * @returns {Promise<void>}
       */
      load: function (config = {}) {
        return asyncLoad().then(function(engineInitializerExports) {
          // Preserve backward compatibility when the config did not have the `serviceWorker` field.
          if (config.serviceWorker == null) {
            config.serviceWorker = {};
          }

          // Backward compatibility: The `serviceWorkerVersion` was originally a module parameter.
          if (config.serviceWorkerVersion != null) {
            config.serviceWorker.serviceWorkerVersion = config.serviceWorkerVersion;
            config.serviceWorkerVersion = undefined;
          }

          // Support module parameter to install a specific serviceWorker.
          const serviceWorkerVersion = config.serviceWorker.serviceWorkerVersion;
          if (serviceWorkerVersion != null && "serviceWorker" in navigator) {
            navigator.serviceWorker.register(
              `flutter_service_worker.js?v=${serviceWorkerVersion}`
            );
          }
          return engineInitializerExports;
        });
      },

      /**
       * (for backwards compatibility)
       * This function loads the main.dart.js, and other assets needed to run the
       * app.
       * 
       * Use this function when you want to include Flutter in a hybrid app.
       * 
       * @param {*} options 
       * @param {*} onEntrypointLoaded 
       */
      loadEntrypoint: function(options) {
        const {
          entrypointUrl = null,
          onEntrypointLoaded = null
        } = options || {};

        // Get the entrypoint URL from the options, or use the default one.
        if (entrypointUrl !== null) {
          entrypointUrl = entrypointUrl;
        }

        return this.load({
          ...options,
        }).then(function(engineInitializerExports) {
          // The engineInitializer is returned from asyncLoad.
          if (onEntrypointLoaded !== null) {
            onEntrypointLoaded(engineInitializerExports);
          }
          return engineInitializerExports;
        });
      }
    };

    // Set the loader for users to access.
    window._flutter.loader = loader;
  }

  /**
   * Find the element with the corresponding ID, and add the `css` to it.
   * If the element doesn't exist, create a new style element.
   * @param {string} id 
   * @param {string} css 
   */
  function setUserStyle(id, css) {
    const style = document.getElementById(id) || document.createElement('style');
    style.textContent = css;
    if (!style.id) {
      style.id = id;
      document.head.appendChild(style);
    }
  }

  /**
   * Adds a stylesheet for the Flutter app. This is for specific Flutter-Web fixes (non-Flutter design).
   */
  function setFlutterStyle() {
    setUserStyle('flutter-style',
      '.flutter-app-snapshot { visibility: hidden; }');
  }

  /**
   * This function is compatible with AMD (RequireJS) modules. It sets up the
   * loader for AMD modules. For non-AMD modules, see the code in {@link setUpNonAMD()}
   * @param {function} define
   */
  function setUpAMD(define) {
    define([], loadESM);
  }

  /**
   * This function sets up the ESM loader. For AMD, see {@link setUpAMD()}.
   */
  function loadESM() {
    /**
    * UMD / AMD Compatibility.
    */
    setUpNonAMD();

    /**
     * ES Module export value.
     */
    return engineInitializer();
  }

  /**
   * UMD Compatibility. This function sets up the loader for non-AMD modules.
   */
  function setUpNonAMD() {
    // Create a style class to help with Flutter app initialization.
    setFlutterStyle();

    // Set up the loader for non-AMD modules.
    loadUMD();
  }

  // Check for RequireJS/AMD.
  // If not AMD, call load() for UMD compatibility.
  if (typeof define === "function" && define.amd) {
    // Export an AMD module.
    setUpAMD(define);
  } else if (typeof exports === "object" && typeof module === "object") {
    // Export a CommonJS module for bundlers.
    module.exports = loadESM();
  } else {
    // Export the auto-detected way.
    setUpNonAMD();
  }

  /**
   * Export the Flutter web SDK version.
   * @internal Used by the Flutter SDK, not for public use.
   */
  window.flutterWebSdkVersion = "3.16.9";
})(); 