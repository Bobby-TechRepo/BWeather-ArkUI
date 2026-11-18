import { Format } from '../common/Format';
import { CAPITALS, CapitalCity } from '../data/Capitals';
import { FailureKind, RequestFailure } from '../data/Http';
import { ForecastRepository } from '../data/WeatherClient';
import { City } from '../model/Models';
import { Status } from './StateTypes';

/** Capitals that share a first letter, for the A–Z list. */
export interface CapitalGroup {
  letter: string;
  cities: CapitalCity[];
}

/** City search with debouncing, plus the built-in capitals (lib/states/cities_cubit.dart). */
@ObservedV2
export class SearchStore {
  /** Wait for the user to stop typing before calling the API. */
  static readonly DEBOUNCE_MS: number = 350;
  /** Open-Meteo returns nothing for 1-character queries. */
  static readonly MIN_QUERY_LENGTH: number = 2;

  @Trace query: string = '';
  @Trace results: City[] = [];
  @Trace status: Status = Status.Initial;

  /** Built-in capitals grouped by first letter (sorted copy; the list itself is shared). */
  readonly groups: CapitalGroup[] = SearchStore.group(CAPITALS);

  private readonly repository: ForecastRepository = new ForecastRepository();
  private timer: number = -1;
  /** Incremented per request; answers to older requests are ignored. */
  private requestId: number = 0;

  get isSearching(): boolean {
    return this.query.trim().length > 0;
  }

  /** Call on every keystroke; the request is debounced. */
  queryChanged(query: string): void {
    this.cancelTimer();
    const trimmed = query.trim();
    this.query = query;
    if (trimmed.length < SearchStore.MIN_QUERY_LENGTH) {
      this.requestId++;
      this.results = [];
      this.status = Status.Initial;
      return;
    }
    this.status = Status.Loading;
    this.timer = setTimeout(() => {
      this.timer = -1;
      this.search(trimmed);
    }, SearchStore.DEBOUNCE_MS);
  }

  /** Runs a search right away (e.g. the user pressed enter). */
  async search(query: string): Promise<void> {
    this.cancelTimer();
    const trimmed = query.trim();
    if (trimmed.length < SearchStore.MIN_QUERY_LENGTH) {
      return;
    }
    const id = ++this.requestId;
    this.status = Status.Loading;
    try {
      const results = await this.repository.search(trimmed, Format.language());
      if (id !== this.requestId) {
        return;
      }
      this.results = results;
      this.status = Status.Success;
    } catch (error) {
      if (id !== this.requestId) {
        return;
      }
      this.results = [];
      // No matches is a successful search with no results, not an error.
      this.status = error instanceof RequestFailure && error.kind === FailureKind.NotFound ? Status.Success : Status.Failure;
    }
  }

  clear(): void {
    this.cancelTimer();
    this.requestId++;
    this.query = '';
    this.results = [];
    this.status = Status.Initial;
  }

  private cancelTimer(): void {
    if (this.timer !== -1) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
  }

  private static group(list: CapitalCity[]): CapitalGroup[] {
    const sorted = list.slice().sort((a: CapitalCity, b: CapitalCity) => a.name.localeCompare(b.name));
    const groups: CapitalGroup[] = [];
    for (const city of sorted) {
      const letter = city.name.charAt(0).toUpperCase();
      if (groups.length === 0 || groups[groups.length - 1].letter !== letter) {
        const group: CapitalGroup = { letter: letter, cities: [] };
        groups.push(group);
      }
      groups[groups.length - 1].cities.push(city);
    }
    return groups;
  }
}
