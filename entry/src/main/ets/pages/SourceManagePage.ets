import { MusicSourceConfig, SourceKind, JsonFieldMapping } from '../models/OnlineTypes';
import { SourceRepository } from '../data/SourceRepository';
import { SourceRegistry } from '../services/online/SourceRegistry';

@Entry
@Component
struct SourceManagePage {
  @State configs: MusicSourceConfig[] = [];
  @State jamendoClientId: string = '';
  @State autoAdd: boolean = true;
  @State showForm: boolean = false;
  @State editingId: string = '';
  @State formName: string = '';
  @State formUrl: string = '';
  @State formKind: number = 0;
  @State formHeaderKey: string = '';
  @State formHeaderValue: string = '';
  @State formListPath: string = '';
  @State formIdPath: string = '';
  @State formTitlePath: string = '';
  @State formArtistPath: string = '';
  @State formStreamPath: string = '';
  @State formDurationPath: string = '';
  @State formCoverPath: string = '';
  @State formDownloadPath: string = '';
  @State formLicenseNamePath: string = '';
  @State formLicenseUrlPath: string = '';

  aboutToAppear(): void {
    this.loadAll();
  }

  private async loadAll(): Promise<void> {
    this.configs = await SourceRepository.getConfigs();
    this.jamendoClientId = await SourceRepository.getJamendoClientId();
    this.autoAdd = await SourceRepository.getAutoAdd();
  }

  private async refreshRegistry(): Promise<void> {
    const configs: MusicSourceConfig[] = await SourceRepository.getConfigs();
    const clientId: string = await SourceRepository.getJamendoClientId();
    SourceRegistry.configure(configs, clientId);
  }

  private findConfig(id: string): MusicSourceConfig | null {
    for (let i = 0; i < this.configs.length; i++) {
      if (this.configs[i].id === id) {
        return this.configs[i];
      }
    }
    return null;
  }

  private async toggleBuiltin(id: string, value: boolean): Promise<void> {
    const config = this.findConfig(id);
    if (!config) {
      return;
    }
    const updated: MusicSourceConfig = {
      id: config.id,
      name: config.name,
      kind: config.kind,
      enabled: value,
      url: config.url,
      mapping: config.mapping,
      headers: config.headers,
      builtin: config.builtin
    };
    const list: MusicSourceConfig[] = this.configs.slice();
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        list[i] = updated;
        break;
      }
    }
    this.configs = list;
    await SourceRepository.saveConfig(updated);
    await this.refreshRegistry();
  }

  private async saveJamendoId(): Promise<void> {
    const value: string = this.jamendoClientId.trim();
    await SourceRepository.setJamendoClientId(value);
    await this.refreshRegistry();
    this.getUIContext().getPromptAction().showToast({ message: 'client_id 已保存' });
  }

  private async toggleAutoAdd(value: boolean): Promise<void> {
    this.autoAdd = value;
    await SourceRepository.setAutoAdd(value);
  }

  private resetFormFields(): void {
    this.formHeaderKey = '';
    this.formHeaderValue = '';
    this.formListPath = '';
    this.formIdPath = '';
    this.formTitlePath = '';
    this.formArtistPath = '';
    this.formStreamPath = '';
    this.formDurationPath = '';
    this.formCoverPath = '';
    this.formDownloadPath = '';
    this.formLicenseNamePath = '';
    this.formLicenseUrlPath = '';
  }

  private openAddForm(): void {
    this.editingId = '';
    this.formName = '';
    this.formUrl = '';
    this.formKind = 0;
    this.resetFormFields();
    this.showForm = true;
  }

  private openEditForm(config: MusicSourceConfig): void {
    this.editingId = config.id;
    this.formName = config.name;
    this.formUrl = config.url ?? '';
    this.formKind = config.kind === 'jsonapi' ? 1 : 0;
    this.resetFormFields();
    if (config.headers) {
      const keys: string[] = Object.keys(config.headers);
      if (keys.length > 0) {
        this.formHeaderKey = keys[0];
        this.formHeaderValue = (config.headers as Record<string, string>)[keys[0]];
      }
    }
    if (config.mapping) {
      const mapping: JsonFieldMapping = config.mapping;
      this.formListPath = mapping.listPath;
      this.formIdPath = mapping.id;
      this.formTitlePath = mapping.title;
      this.formArtistPath = mapping.artist;
      this.formStreamPath = mapping.streamUrl;
      this.formDurationPath = mapping.duration ?? '';
      this.formCoverPath = mapping.coverUrl ?? '';
      this.formDownloadPath = mapping.downloadUrl ?? '';
      this.formLicenseNamePath = mapping.licenseName ?? '';
      this.formLicenseUrlPath = mapping.licenseUrl ?? '';
    }
    this.showForm = true;
  }

  private isFormValid(): boolean {
    if (this.formName.trim().length === 0 || this.formUrl.trim().length === 0) {
      return false;
    }
    if (!this.formUrl.startsWith('http://') && !this.formUrl.startsWith('https://')) {
      return false;
    }
    if (this.formKind === 1) {
      if (this.formUrl.indexOf('{keyword}') < 0) {
        return false;
      }
      if (this.formListPath.trim().length === 0 || this.formIdPath.trim().length === 0 ||
        this.formTitlePath.trim().length === 0 || this.formArtistPath.trim().length === 0 ||
        this.formStreamPath.trim().length === 0) {
        return false;
      }
    }
    const hasHeaderKey: boolean = this.formHeaderKey.trim().length > 0;
    const hasHeaderValue: boolean = this.formHeaderValue.trim().length > 0;
    if (hasHeaderKey !== hasHeaderValue) {
      return false;
    }
    return true;
  }

  private async submitForm(): Promise<void> {
    if (!this.isFormValid()) {
      this.getUIContext().getPromptAction().showToast({ message: '请完整填写必填项（JSON 需含字段映射）' });
      return;
    }
    const kind: SourceKind = this.formKind === 1 ? 'jsonapi' : 'rss';
    let id: string = this.editingId;
    if (id.length === 0) {
      id = SourceRepository.generateCustomId();
    }
    let headers: Record<string, string> | undefined;
    if (this.formHeaderKey.trim().length > 0 && this.formHeaderValue.trim().length > 0) {
      headers = {};
      headers[this.formHeaderKey.trim()] = this.formHeaderValue.trim();
    }
    let mapping: JsonFieldMapping | undefined;
    if (kind === 'jsonapi') {
      mapping = {
        listPath: this.formListPath.trim(),
        id: this.formIdPath.trim(),
        title: this.formTitlePath.trim(),
        artist: this.formArtistPath.trim(),
        streamUrl: this.formStreamPath.trim(),
        duration: this.formDurationPath.trim().length > 0 ? this.formDurationPath.trim() : undefined,
        coverUrl: this.formCoverPath.trim().length > 0 ? this.formCoverPath.trim() : undefined,
        downloadUrl: this.formDownloadPath.trim().length > 0 ? this.formDownloadPath.trim() : undefined,
        licenseName: this.formLicenseNamePath.trim().length > 0 ? this.formLicenseNamePath.trim() : undefined,
        licenseUrl: this.formLicenseUrlPath.trim().length > 0 ? this.formLicenseUrlPath.trim() : undefined
      };
    }
    const config: MusicSourceConfig = {
      id: id,
      name: this.formName.trim(),
      kind: kind,
      enabled: true,
      url: this.formUrl.trim(),
      mapping: mapping,
      headers: headers
    };
    await SourceRepository.saveConfig(config);
    this.showForm = false;
    await this.loadAll();
    await this.refreshRegistry();
  }

  private askDelete(config: MusicSourceConfig): void {
    this.getUIContext().showActionSheet({
      title: `删除音源「${config.name}」？`,
      message: '',
      sheets: [
        {
          title: '删除',
          action: (): void => {
            this.doDelete(config.id);
          }
        }
      ]
    });
  }

  private async doDelete(id: string): Promise<void> {
    await SourceRepository.deleteConfig(id);
    await this.loadAll();
  }

  @Builder
  sectionHeader(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor($r('app.color.text_sub'))
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 8, right: 16 })
  }

  @Builder
  builtinRow(config: MusicSourceConfig) {
    Row() {
      Column() {
        Text(config.name)
          .fontSize(15)
          .fontColor($r('app.color.text_main'))
        Text(config.id === 'jamendo' ? '需填写 client_id' : '无需密钥，直接可用')
          .fontSize(12)
          .fontColor($r('app.color.text_sub'))
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: config.enabled })
        .selectedColor($r('app.color.primary'))
        .onChange((value: boolean) => {
          this.toggleBuiltin(config.id, value);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  customRow(config: MusicSourceConfig) {
    Row() {
      Column() {
        Text(config.name)
          .fontSize(15)
          .fontColor($r('app.color.text_main'))
        Text((config.kind === 'jsonapi' ? 'JSON · ' : 'RSS · ') + (config.url ?? ''))
          .fontSize(11)
          .fontColor($r('app.color.text_sub'))
          .margin({ top: 2 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: config.enabled })
        .selectedColor($r('app.color.primary'))
        .margin({ right: 8 })
        .onChange((value: boolean) => {
          this.toggleBuiltin(config.id, value);
        })
      Text('编辑')
        .fontSize(13)
        .fontColor($r('app.color.primary'))
        .margin({ right: 12 })
        .onClick(() => this.openEditForm(config))
      Text('删除')
        .fontSize(13)
        .fontColor('#E85A5A')
        .onClick(() => this.askDelete(config))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  fieldInput(label: string, value: string, placeholder: string, required: boolean,
    onInput: (value: string) => void) {
    Column() {
      Text(label + (required ? ' *' : ''))
        .fontSize(13)
        .fontColor($r('app.color.text_sub'))
        .width('100%')
        .margin({ bottom: 6 })
      TextInput({ text: value, placeholder: placeholder })
        .fontSize(14)
        .height(40)
        .onChange((v: string) => {
          onInput(v);
        })
    }
    .width('100%')
    .margin({ top: 12 })
  }

  @Builder
  formSheet() {
    Column() {
      Text(this.editingId.length > 0 ? '编辑音源' : '添加音源')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_main'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 16, bottom: 12 })

      Scroll() {
        Column() {
          Text('类型')
            .fontSize(13)
            .fontColor($r('app.color.text_sub'))
            .width('100%')
            .margin({ bottom: 6 })
          Row() {
            ForEach(['RSS 播客', 'JSON 接口'], (label: string, index: number) => {
              Text(label)
                .fontSize(13)
                .fontColor(this.formKind === index ? Color.White : $r('app.color.text_main'))
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
                .height(34)
                .borderRadius(8)
                .backgroundColor(this.formKind === index ? $r('app.color.primary') : $r('app.color.bg_gray'))
                .onClick(() => {
                  this.formKind = index;
                })
            }, (label: string) => label)
          }
          .width('100%')

          this.fieldInput('名称', this.formName, '我的音源', true, (v: string): void => {
            this.formName = v;
          })

          Column() {
            Text((this.formKind === 0 ? 'Feed URL' : 'URL 模板（需包含 {keyword}）') + ' *')
              .fontSize(13)
              .fontColor($r('app.color.text_sub'))
              .width('100%')
              .margin({ bottom: 6 })
            TextInput({
              text: this.formUrl,
              placeholder: this.formKind === 0 ? 'https://example.com/feed.xml' : 'https://example.com/api?q={keyword}'
            })
              .fontSize(14)
              .height(40)
              .onChange((v: string) => {
                this.formUrl = v;
              })
          }
          .width('100%')
          .margin({ top: 12 })

          Text('自定义请求头（选填，最多 1 个）')
            .fontSize(13)
            .fontColor($r('app.color.text_sub'))
            .width('100%')
            .margin({ top: 18 })
          Row() {
            Column() {
              Text('Header 名称')
                .fontSize(12)
                .fontColor($r('app.color.text_sub'))
                .width('100%')
                .margin({ bottom: 4 })
              TextInput({ text: this.formHeaderKey, placeholder: '如 Referer' })
                .fontSize(13)
                .height(38)
                .onChange((v: string) => {
                  this.formHeaderKey = v;
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Column() {
              Text('Header 值')
                .fontSize(12)
                .fontColor($r('app.color.text_sub'))
                .width('100%')
                .margin({ bottom: 4 })
              TextInput({ text: this.formHeaderValue, placeholder: 'https://...' })
                .fontSize(13)
                .height(38)
                .onChange((v: string) => {
                  this.formHeaderValue = v;
                })
            }
            .layoutWeight(1)
            .margin({ left: 10 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .margin({ top: 8 })

          if (this.formKind === 1) {
            Text('字段映射（相对每个结果项的路径）')
              .fontSize(13)
              .fontColor($r('app.color.text_sub'))
              .width('100%')
              .margin({ top: 18 })
            this.fieldInput('结果列表路径', this.formListPath, '如 data.results', true, (v: string): void => {
              this.formListPath = v;
            })
            this.fieldInput('ID 路径', this.formIdPath, '如 id', true, (v: string): void => {
              this.formIdPath = v;
            })
            this.fieldInput('标题路径', this.formTitlePath, '如 title', true, (v: string): void => {
              this.formTitlePath = v;
            })
            this.fieldInput('艺术家路径', this.formArtistPath, '如 artist', true, (v: string): void => {
              this.formArtistPath = v;
            })
            this.fieldInput('播放地址路径', this.formStreamPath, '如 stream_url', true, (v: string): void => {
              this.formStreamPath = v;
            })
            this.fieldInput('时长路径（单位秒，选填）', this.formDurationPath, '如 duration', false,
              (v: string): void => {
                this.formDurationPath = v;
              })
            this.fieldInput('封面路径（选填）', this.formCoverPath, '如 cover_url', false, (v: string): void => {
              this.formCoverPath = v;
            })
            this.fieldInput('下载地址路径（选填）', this.formDownloadPath, '如 download_url', false,
              (v: string): void => {
                this.formDownloadPath = v;
              })
            this.fieldInput('授权名称路径（选填）', this.formLicenseNamePath, '如 license_name', false,
              (v: string): void => {
                this.formLicenseNamePath = v;
              })
            this.fieldInput('授权链接路径（选填）', this.formLicenseUrlPath, '如 license_url', false,
              (v: string): void => {
                this.formLicenseUrlPath = v;
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .constraintSize({ maxHeight: 520 })
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      Row() {
        Text('取消')
          .fontSize(15)
          .fontColor($r('app.color.text_sub'))
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(42)
          .onClick(() => {
            this.showForm = false;
          })
        Text('保存')
          .fontSize(15)
          .fontColor(this.isFormValid() ? Color.White : $r('app.color.text_sub'))
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(42)
          .borderRadius(21)
          .backgroundColor(this.isFormValid() ? $r('app.color.primary') : $r('app.color.bg_gray'))
          .margin({ left: 12 })
          .onClick(() => this.submitForm())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 24 })
    }
    .width('100%')
    .backgroundColor($r('app.color.bg_white'))
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        Row() {
          Text('←')
            .fontSize(24)
            .fontColor($r('app.color.text_main'))
            .width(36)
            .onClick(() => this.getUIContext().getRouter().back())
          Text('音源管理')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_main'))
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .margin({ right: 36 })
        }
        .width('100%')
        .height(56)
        .padding({ left: 12, right: 12 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor($r('app.color.bg_white'))

        Divider().color($r('app.color.divider'))

        Scroll() {
          Column() {
            this.sectionHeader('内置音源')
            Column() {
              ForEach(this.configs, (config: MusicSourceConfig) => {
                if (config.builtin === true) {
                  this.builtinRow(config)
                  Divider().color($r('app.color.divider')).margin({ left: 16 })
                }
              }, (config: MusicSourceConfig) => config.id)
            }
            .backgroundColor($r('app.color.bg_white'))

            this.sectionHeader('Jamendo client_id')
            Column() {
              Row() {
                TextInput({ text: this.jamendoClientId, placeholder: '填写 client_id' })
                  .fontSize(14)
                  .height(40)
                  .layoutWeight(1)
                  .onChange((value: string) => {
                    this.jamendoClientId = value;
                  })
                Text('保存')
                  .fontSize(14)
                  .fontColor($r('app.color.primary'))
                  .margin({ left: 12 })
                  .onClick(() => this.saveJamendoId())
              }
              .width('100%')
              .padding(16)

              Text('可到 developer.jamendo.com 免费申请，填写保存后即时生效')
                .fontSize(12)
                .fontColor($r('app.color.text_sub'))
                .width('100%')
                .padding({ left: 16, right: 16, bottom: 14 })
            }
            .backgroundColor($r('app.color.bg_white'))

            this.sectionHeader('自定义音源')
            Column() {
              ForEach(this.configs, (config: MusicSourceConfig) => {
                if (config.builtin !== true) {
                  this.customRow(config)
                  Divider().color($r('app.color.divider')).margin({ left: 16 })
                }
              }, (config: MusicSourceConfig) => config.id)
              Row() {
                Text('+ 添加音源')
                  .fontSize(14)
                  .fontColor($r('app.color.primary'))
              }
              .width('100%')
              .height(48)
              .justifyContent(FlexAlign.Center)
              .onClick(() => this.openAddForm())
            }
            .backgroundColor($r('app.color.bg_white'))

            this.sectionHeader('下载设置')
            Column() {
              Row() {
                Text('下载后自动加入本地库')
                  .fontSize(15)
                  .fontColor($r('app.color.text_main'))
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.autoAdd })
                  .selectedColor($r('app.color.primary'))
                  .onChange((value: boolean) => {
                    this.toggleAutoAdd(value);
                  })
              }
              .width('100%')
              .height(52)
              .padding({ left: 16, right: 16 })
              .alignItems(VerticalAlign.Center)
            }
            .backgroundColor($r('app.color.bg_white'))

            Column()
              .height(20)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_gray'))
    .bindSheet($$this.showForm, this.formSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: false,
      backgroundColor: $r('app.color.bg_white')
    })
  }
}
