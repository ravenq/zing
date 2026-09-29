// AppStorage 键名
export class AppStorageKey {
  static readonly CURRENT_SONG = 'currentSong';
  static readonly PLAYER_STATE = 'playerState';
  static readonly CURRENT_POSITION = 'currentPosition';
  static readonly PLAY_MODE = 'playMode';
  static readonly PLAY_QUEUE = 'playQueue';
  static readonly CURRENT_INDEX = 'currentIndex';
  static readonly ALL_SONGS = 'allSongs';
  static readonly FAVORITE_SONGS = 'favoriteSongs';
  static readonly RECENT_SONGS = 'recentSongs';
  static readonly PLAYLISTS = 'playlists';
  static readonly IS_PLAYING_PAGE_SHOW = 'isPlayingPageShow';
}

// 存储
export class StorageName {
  static readonly FAVORITE = 'favorite_storage';
  static readonly HISTORY = 'history_storage';
  static readonly PLAYLIST = 'playlist_storage';
  static readonly MUSIC_CACHE = 'music_cache_storage';
  static readonly SETTINGS = 'settings_storage';
  static readonly SOURCE = 'source_storage';
}

// 默认值
export class DefaultValue {
  static readonly MAX_HISTORY = 100;
  static readonly MAX_RECENT_DISPLAY = 50;
  static readonly SCAN_BATCH_SIZE = 100;
}

// 页面路由
export class RouterPath {
  static readonly INDEX = 'pages/Index';
  static readonly SONG_LIST = 'pages/SongListPage';
  static readonly ARTIST_DETAIL = 'pages/ArtistDetailPage';
  static readonly ALBUM_DETAIL = 'pages/AlbumDetailPage';
  static readonly PLAYLIST_DETAIL = 'pages/PlaylistDetailPage';
  static readonly SEARCH = 'pages/SearchPage';
  static readonly PLAYING = 'pages/PlayingPage';
  static readonly ONLINE_SEARCH = 'pages/OnlineSearchPage';
  static readonly SOURCE_MANAGE = 'pages/SourceManagePage';
  static readonly WEB_SNIFFER = 'pages/WebSnifferPage';
}
