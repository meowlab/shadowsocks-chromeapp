/*
 * Copyright (C) 2015  Sunny <ratsunny@gmail.com>
 *
 * This file is part of Shadowsocks-NaCl.
 *
 * Shadowsocks-NaCl is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Shadowsocks-NaCl is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


angular.module('shadowsocks').service('storage',
  ['$q', '$rootScope', function($q, $rootScope) {

  var defaultArea = 'local';

  this.setDefaultArea = function(area) {
    defaultArea = area;
  };

  this.get = function(keys, area) {
    if (area == null)
      area = defaultArea;
    var deferred = $q.defer();
    chrome.storage[area].get(keys, function(items) {
      if (chrome.runtime.lastError)
        deferred.reject(chrome.runtime.lastError);
      deferred.resolve(items);
    });
    return deferred.promise;
  };

  this.set = function(items, area) {
    if (area == null)
      area = defaultArea;
    var deferred = $q.defer();
    chrome.storage[area].set(items, function() {
      if (chrome.runtime.lastError)
        deferred.reject(chrome.runtime.lastError);
      deferred.resolve();
    });
    return deferred.promise;
  };

  this.remove = function(keys, area) {
    if (area == null)
      area = defaultArea;
    var deferred = $q.defer();
    chrome.storage[area].remove(keys, function() {
      if (chrome.runtime.lastError)
        deferred.reject(chrome.runtime.lastError);
      deferred.resolve();
    });
    return deferred.promise;
  };

  this.clear = function(area) {
    if (area == null)
      area = defaultArea;
    var deferred = $q.defer();
    chrome.storage[area].clear(function() {
      if (chrome.runtime.lastError)
        deferred.reject(chrome.runtime.lastError);
      deferred.resolve();
    });
    return deferred.promise;
  };

  chrome.storage.onChanged.addListener(function(changes, areaName) {
    $rootScope.$broadcast('storageChanged', changes, areaName);
  });
}]);


angular.module('shadowsocks').service('ProfileManager',
  ['$rootScope', 'storage', function($rootScope, storage) {

  var createUUID = function() {
    var d = Date.now();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = (d + Math.random() * 16) % 16 | 0;
        d = Math.floor(d / 16);
        return (c == 'x' ? r : (r & 0x3 | 0x8)).toString(16);
    });
  };

  var createProfile = function() {
    return {
      id: createUUID(),
      server: null,
      server_port: null,
      password: null,
      local_port: null,
      method: 'aes-256-cfb',
      timeout: 300
    }
  };

  var _this = this;
  storage.get(['config', 'profiles']).then(function(result) {
    _this.config = result.config || {currentProfile: null};
    _this.profiles = result.profiles || {};
    _this.currentProfile = angular.copy(_this.profiles[_this.config.currentProfile] || createProfile());
    $rootScope.$broadcast('ProfileManagerReady');
  });

  this.createProfile = function() {
    return _this.currentProfile = createProfile();
  };

  this.switchProfile = function(profileId) {
    _this.currentProfile = angular.copy(_this.profiles[profileId]);
    return _this.currentProfile;
  };

  this.saveAsCurrent = function() {
    _this.profiles[_this.currentProfile.id] = _this.currentProfile;
    return storage.get(['config']).then(function(result) {
      result.config = result.config || {};
      result.config.currentProfile = _this.currentProfile.id;
      result.profiles = _this.profiles;
      return storage.set(result);
    });
  };

  this.deleteProfile = function(profileId) {
    delete _this.profiles[profileId];
    return storage.get(['config']).then(function(result) {
      result.config = result.config || {};
      if (result.config.currentProfile == profileId) {
        result.config.currentProfile = Object.keys(_this.profiles)[0] || null;
      }
      result.profiles = _this.profiles;
      return storage.set(result).then(function() {
        _this.currentProfile = angular.copy(_this.profiles[_this.config.currentProfile] || createProfile());
      });
    });
  };

}]);


angular.module('shadowsocks').filter('contains', function() {
  return function(input, data) {
    var result = [];
    angular.forEach(input, function(info) {
      if (data && info.name.indexOf(data) !== -1) {
        this.push(info);
      }
    }, result);
    return result;
  };
});