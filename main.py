import time
import copy

from api.api_citybikewien import CitybikeWienApi
from api.api_oebb import OeBBApi
from api.api_wrlinien import WrLinienApi
from api.api_yrno import YRNOApi
from worker import Worker
from display.display_driver import UIDriver
from utils import get_config, get_logger

logger = get_logger(__name__)


class NoDataException(Exception):
    pass


def _merge_api_data(wrlinien, oebb, citybikewien):
    # merge wrlinien and oebb
    unmerged_stations = copy.deepcopy(wrlinien['stations']) + oebb  # do not make changes to original dicts
    stations = []
    for unmerged_station in unmerged_stations:
        exists = False
        for station in stations:
            if unmerged_station['name'] == station['name']:
                station['lines'].extend(unmerged_station['lines'])  # does not merge same lines, just adds to station
                exists = True
        if exists is False:
            stations.append(unmerged_station)

    # merge citybikewien to merged
    for bike_station in citybikewien:
        exists = False
        for station in stations:
            if bike_station['name'] == station['name']:
                station['citybikewien'] = bike_station
                exists = True
                break
        if not exists:
            stations.append({  # add a new station only for citybikewien to stations
                'name': bike_station['name'],
                'citybikewien': bike_station
            })
    return {'stations': stations, 'lastUpdate': wrlinien['lastUpdate']}


def _add_walking_time(transport_data):
    conf = get_config()
    for station in transport_data['stations']:
        for walkingTime in conf['stations']['walkingTime']:
            if station['name'] == walkingTime['station']:
                station['walkingTime'] = walkingTime['time']
    return transport_data


def _check_api_data(wrlinien, oebb, citybikewien):
    error_msg = " Api Data is None"
    if wrlinien is None:
        raise NoDataException("Wr Linien" + error_msg)

    if oebb is None:
        raise NoDataException("ÖBB" + error_msg)

    if citybikewien is None:
        raise NoDataException("Citybikes" + error_msg)


def _to_display_data(wrlinien, oebb, citybikewien):
    _check_api_data(wrlinien, oebb, citybikewien)
    merged_data = _merge_api_data(wrlinien, oebb, citybikewien)
    walking_time_data = _add_walking_time(merged_data)
    return walking_time_data


def _wait_for_next_udpate(last_update):
    conf = get_config()
    update_delta = last_update - time.time() + conf['display']['updateInterval']
    if update_delta > 0:
        logger.info('sleeping for %d seconds before next cycle' % update_delta)
        time.sleep(update_delta)
    else:
        logger.warning('skipping sleep, late for next cycle by %d seconds' % (update_delta * -1))


def main():
    logger.info("Application Start!")

    wrlinien_api = WrLinienApi()
    oebb_api = OeBBApi()
    citybikewien_api = CitybikeWienApi()
    weather_api = YRNOApi()
    ui_driver = UIDriver()

    last_exception = {  # keep track of exceptions
        "type": None,
        "counter": 0
    }

    while True:
        try:
            logger.info("Cycle Start!")
            last_update = time.time()

            threads = [
                Worker("wrlinien_api", wrlinien_api),
                Worker("oebb_api", oebb_api),
                Worker("citybikewien_api", citybikewien_api),
                Worker("weather_api", weather_api)
            ]
            for t in threads:
                t.start()
            for t in threads:
                t.join()

            traffic_data = _to_display_data(wrlinien_api.data, oebb_api.data, citybikewien_api.data)
            logger.info("Traffic Data: %s" % traffic_data)
            ui_driver.display(traffic_data, weather_api.data)

            _wait_for_next_udpate(last_update)

        except Exception as err:
            # TODO replace with downtime
            # sleeps one hour if error between 1 and 5 a.m., where less traffic info is available
            hour = int(time.strftime("%H"))
            if 1 <= hour <= 5:
                logger.exception(err)
                logger.warning("sleeping for an hour")
                time.sleep(3600)
            else:  # exception handling
                if last_exception['counter'] >= 3:  # if happened 3 times already, raise
                    raise err
                else:
                    if last_exception['type'] != type(err).__name__:
                        last_exception['type'] = type(err).__name__  # track new exception type instead
                        last_exception['counter'] = 1
                        logger.error("First time catching exception %s:" % last_exception['type'])
                        # logger.exception(err)  # log, but do not raise
                        time.sleep(2)
                    else:
                        last_exception['counter'] += 1  # if exception already occurred, increment counter
                        logger.error("Caught exception %s already %d times:" % (last_exception['type'], last_exception['counter']))
                        # logger.exception(err)  # log, but do not raise
                        time.sleep(2)
                        # TODO display image when oeffis-paper has crashed hard


if __name__ == "__main__":
    main()