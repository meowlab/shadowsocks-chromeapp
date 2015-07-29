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


angular.module('shadowsocks').controller('shadowsocks',
  ['$scope', '$rootScope', '$timeout', 'ProfileManager', function($scope, $rootScope, $timeout, ProfileManager) {

  var generateProfileKeys = function() {
    var result = [], profile;
    for (key in $scope.profiles) {
      profile = $scope.profiles[key];
      result.push({name: profile.server + ':' + profile.server_port, key: key, server: profile.server});
    }
    return result;
  };

  $rootScope.$on('ProfileManagerReady', function() {
    $scope.allowSave = true;
    $scope.currentProfile = ProfileManager.currentProfile;
    $scope.profiles = ProfileManager.profiles;
    $scope.profileKeys = generateProfileKeys();
  });

  var timeoutPromise = null, originAlert = null;
  chrome.runtime.onMessage.addListener(function(msg, sender, sendResponse) {
    if (msg.type !== "LOGMSG") return;
    if (msg.timeout) {
      if (timeoutPromise)
        $timeout.cancel(timeoutPromise);
      else
        originAlert = $scope.alert;
      timeoutPromise = $timeout(function() {
        $scope.alert = originAlert;
        timeoutPromise = null;
      }, msg.timeout);
    }
    $scope.alert = msg.data;
    $scope.$apply();
  });

  $scope.createNewProfile = function() {
    $scope.currentProfile = ProfileManager.createProfile();
  };

  $scope.switchProfile = function(profileId) {
    $scope.currentProfile = ProfileManager.switchProfile(profileId);
  };

  $scope.saveAndApply = function() {
    if (!$scope.currentProfile.server   || !$scope.currentProfile.server_port ||
        !$scope.currentProfile.password || !$scope.currentProfile.local_port ||
        !$scope.currentProfile.method   || !$scope.currentProfile.timeout) {
      $scope.alert = { type: 'danger', msg: 'Fill all blanks before save' };
      return;
    }

    $scope.allowSave = false;
    ProfileManager.saveAsCurrent().then(function() {
      $scope.profiles = ProfileManager.profiles;
      $scope.profileKeys = generateProfileKeys();

      chrome.runtime.sendMessage({
        type: "SOCKS5OP",
        config: $scope.currentProfile
      }, function(info) {
        $scope.allowSave = true;
        $scope.alert = { type: 'info', msg: info };
        $scope.$apply();
      });

    });
  };

  $scope.deleteCurrentProfile = function() {
    ProfileManager.deleteProfile($scope.currentProfile.id).then(function() {
      $scope.profiles = ProfileManager.profiles;
      $scope.currentProfile = ProfileManager.currentProfile;
      $scope.profileKeys = generateProfileKeys();
    });
  };

  $scope.reloadApp = function() {
    chrome.runtime.reload();
  };

  $scope.about = function() {
    window.open('https://github.com/shadowsocks/shadowsocks-chromeapp');
  };
}]);