import { MyMusicPage } from './MyMusicPage';
import { PlaylistPage } from './PlaylistPage';
import { CategoryPage } from './CategoryPage';
import { SettingsPage } from './SettingsPage';
import { PlayingPage } from './PlayingPage';
import { MiniPlayerBar } from '../components/MiniPlayerBar';
import { AppStorageKey } from '../common/Constants';

@Entry
@Component
struct Index {
  @StorageLink(AppStorageKey.IS_PLAYING_PAGE_SHOW) isPlayingPageShow: boolean = false;
  @State currentIndex: number = 0;

  @Builder
  playingSheet() {
    PlayingPage();
  }

  @Builder
  tabIconMine() {
    SymbolGlyph($r('sys.symbol.music'))
      .fontSize(24)
      .fontColor([this.currentIndex === 0 ? $r('app.color.primary') : $r('app.color.text_sub')])
      .renderingStrategy(SymbolRenderingStrategy.SINGLE)
  }

  @Builder
  tabIconPlaylist() {
    SymbolGlyph($r('sys.symbol.list_bullet'))
      .fontSize(24)
      .fontColor([this.currentIndex === 1 ? $r('app.color.primary') : $r('app.color.text_sub')])
      .renderingStrategy(SymbolRenderingStrategy.SINGLE)
  }

  @Builder
  tabIconCategory() {
    SymbolGlyph($r('sys.symbol.square_grid_2x2'))
      .fontSize(24)
      .fontColor([this.currentIndex === 2 ? $r('app.color.primary') : $r('app.color.text_sub')])
      .renderingStrategy(SymbolRenderingStrategy.SINGLE)
  }

  @Builder
  tabIconSettings() {
    SymbolGlyph($r('sys.symbol.gearshape'))
      .fontSize(24)
      .fontColor([this.currentIndex === 3 ? $r('app.color.primary') : $r('app.color.text_sub')])
      .renderingStrategy(SymbolRenderingStrategy.SINGLE)
  }

  @Builder
  tabBar(title: string, index: number) {
    Column() {
      if (index === 0) {
        this.tabIconMine()
      } else if (index === 1) {
        this.tabIconPlaylist()
      } else if (index === 2) {
        this.tabIconCategory()
      } else {
        this.tabIconSettings()
      }
      Text(title)
        .fontSize(10)
        .fontColor(this.currentIndex === index
          ? $r('app.color.primary')
          : $r('app.color.text_sub'))
        .margin({ top: 2 })
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
        TabContent() {
          MyMusicPage()
        }
        .tabBar(this.tabBar('我的', 0))

        TabContent() {
          PlaylistPage()
        }
        .tabBar(this.tabBar('歌单', 1))

        TabContent() {
          CategoryPage()
        }
        .tabBar(this.tabBar('分类', 2))

        TabContent() {
          SettingsPage()
        }
        .tabBar(this.tabBar('设置', 3))
      }
      .layoutWeight(1)
      .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        this.currentIndex = index;
      })

      MiniPlayerBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_gray'))
    .bindSheet($$this.isPlayingPageShow, this.playingSheet(), {
      height: SheetSize.LARGE,
      dragBar: true,
      backgroundColor: $r('app.color.bg_white')
    })
  }
}
