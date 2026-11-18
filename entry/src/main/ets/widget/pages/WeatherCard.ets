/**
 * Home-screen card: current conditions for the user's location (or first
 * saved city), like the Android widget (res/layout/weather_widget.xml).
 * The values come from EntryFormAbility (model/CardData.ets); cards can't
 * read app state directly, so everything arrives as plain strings.
 */
let storage = new LocalStorage();

@Entry(storage)
@Component
struct WeatherCard {
  @LocalStorageProp('ready') ready: boolean = false;
  @LocalStorageProp('place') place: string = '';
  @LocalStorageProp('temperature') temperature: string = '--°';
  @LocalStorageProp('condition') condition: string = '';
  @LocalStorageProp('icon') icon: string = 'partly_day';
  @LocalStorageProp('range') range: string = '';
  @LocalStorageProp('updated') updated: string = '';

  /** Artwork for CardDataUtil.iconKey (only resources named here can be used by a card). */
  artwork(key: string): Resource {
    switch (key) {
      case 'clear_day':
        return $r('app.media.wx_clear_day_fill');
      case 'clear_night':
        return $r('app.media.wx_clear_night_fill');
      case 'partly_night':
        return $r('app.media.wx_partly_cloudy_night_fill');
      case 'overcast':
        return $r('app.media.wx_overcast_fill');
      case 'fog_day':
        return $r('app.media.wx_fog_day_fill');
      case 'fog_night':
        return $r('app.media.wx_fog_night_fill');
      case 'drizzle':
        return $r('app.media.wx_drizzle_fill');
      case 'rain':
        return $r('app.media.wx_overcast_rain_fill');
      case 'snow':
        return $r('app.media.wx_snow_fill');
      case 'thunder_day':
        return $r('app.media.wx_thunderstorms_day_fill');
      case 'thunder_night':
        return $r('app.media.wx_thunderstorms_night_fill');
      default:
        return $r('app.media.wx_partly_cloudy_day_fill');
    }
  }

  build() {
    Column() {
      Text(this.ready ? this.place : '')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.card_text'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row() {
        Text(this.ready ? this.temperature : '--°')
          .fontSize(40)
          .fontColor($r('app.color.card_accent'))
          .layoutWeight(1)
        Image(this.artwork(this.icon))
          .width(52)
          .height(52)
          .objectFit(ImageFit.Contain)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.ready) {
        Text(this.condition)
          .fontSize(13)
          .fontColor($r('app.color.card_text'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Blank()
        Text(this.range)
          .fontSize(12)
          .fontColor($r('app.color.card_muted'))
          .maxLines(1)
          .width('100%')
        Text(this.updated)
          .fontSize(11)
          .fontColor($r('app.color.card_muted'))
          .maxLines(1)
          .width('100%')
      } else {
        Blank()
        Text($r('app.string.card_open_app'))
          .fontSize(13)
          .fontColor($r('app.color.card_text'))
          .maxLines(2)
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.card_background'))
    .onClick(() => {
      // Tapping the card opens the app.
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility'
      });
    })
  }
}
