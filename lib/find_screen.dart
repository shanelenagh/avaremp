import 'package:avaremp/geo_calculations.dart';
import 'package:avaremp/longpress_widget.dart';
import 'package:avaremp/storage.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'chart.dart';
import 'constants.dart';
import 'package:avaremp/destination/destination.dart';
import 'gps.dart';
import 'data/main_database_helper.dart';
import 'main_screen.dart';

class FindScreen extends StatefulWidget {
  FindScreen({super.key});
  @override
  State<StatefulWidget> createState() => FindScreenState();

  final ScrollController controller = ScrollController();
}

class FindScreenState extends State<FindScreen> {

  List<Destination>? _currentItems;
  String _searchText = "";
  bool _recent = true;
  int _runwayLength = 0;

  Future<bool> showDestination(BuildContext context, Destination destination) async {
    bool? exitResult = await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return LongPressWidget(destination: destination);
      },
    );
    return exitResult ?? false;
  }

  @override
  Widget build(BuildContext context) {
    bool searching = true;
    return FutureBuilder(
      // this is a mix of sqlite and realm, so we need to wait for the result and for realm, do a future as dummy
      future: _searchText.isNotEmpty? (MainDatabaseHelper.db.findDestinations(_searchText)) : (_recent ? Future.value(Storage().realmHelper.getRecent()) : MainDatabaseHelper.db.findNearestAirportsWithRunways(Gps.toLatLng(Storage().position), _runwayLength)), // find recent when not searching
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          _currentItems = snapshot.data;
          searching = false;
        }
        return _makeContent(_currentItems, searching);
      },
    );
  }

  Widget _makeContent(List<Destination>? items, bool searching) {

    GeoCalculations geo = GeoCalculations();
    LatLng position = Gps.toLatLng(Storage().position);

    return Container(
        padding: EdgeInsets.fromLTRB(10, 0, 20, Constants.bottomPaddingSize(context)),
        child : Stack(children: [
          Align(alignment: Alignment.center, child: searching? const CircularProgressIndicator() : const SizedBox(width: 0, height:  0,),), // search indication
          Column (children: [
            Expanded(
                flex: 2,
                child: TextFormField(
                    decoration: const InputDecoration(border: UnderlineInputBorder(), labelText: "Find"),
                    onChanged: (value) {
                      setState(() {
                        _searchText = value;
                        searching = true;
                        items != null && items.isNotEmpty ? widget.controller.jumpTo(0) : ();
                      });
                    },
                )
            ),
            Expanded(
                flex: 7,
                child: null == items ? Container() : ListView.separated(
                  itemCount: items.length,
                  padding: const EdgeInsets.all(5),
                  controller: widget.controller,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Dismissible( // able to delete with swipe
                      background: Container(alignment: Alignment.centerRight,child: const Icon(Icons.delete_forever),),
                      key: Key(Storage().getKey()),
                      direction: DismissDirection.endToStart,
                      onDismissed:(direction) {
                        // Remove the item from the data source.
                        Storage().realmHelper.deleteRecent(item);
                        setState(() {
                          items.removeAt(index);
                        });
                      },
                      child: ListTile(
                        title: Row(
                            children:[
                              Text(item.locationID),
                            ]
                        ),
                        subtitle: item.type != Destination.typeGps ?
                          Text("${item.facilityName} ( ${item.type} )") :
                          Row(
                              children: [
                                Expanded(flex: 1, child:TextField(
                                    onSubmitted: (value) {
                                      setState(() {
                                        Destination d = GpsDestination(
                                            locationID: item.locationID,
                                            type: item.type,
                                            facilityName: value,
                                            coordinate: item.coordinate);
                                        Storage().realmHelper.addRecent(d);
                                      });
                                    },
                                    controller: TextEditingController()..text = item.facilityName,
                                )),
                                const Expanded(flex: 1, child:Text("(GPS)"))
                              ]
                          ),
                        dense: true,
                        isThreeLine: true,
                        trailing: TextButton(
                          onPressed: () {
                            Storage().realmHelper.addRecent(item);
                            Storage().settings.setCenterLongitude(item.coordinate.longitude);
                            Storage().settings.setCenterLatitude(item.coordinate.latitude);
                            Storage().settings.setZoom(ChartCategory.chartTypeToZoom(Storage().settings.getChartType()).toDouble());
                            MainScreenState.gotoMap();
                          },
                          child: Text("${GeoCalculations.getMagneticHeading(geo.calculateBearing(position, item.coordinate), geo.getVariation(item.coordinate)).round()}\u00b0@${geo.calculateDistance(item.coordinate, position).round()}")
                        ),
                        onTap: () {
                          setState(() {
                            showDestination(context, item);
                          });
                        },
                        leading: DestinationFactory.getIcon(item.type, Theme.of(context).colorScheme.primary)
                      ),
                    );
                  },
                  separatorBuilder: (context, index) {
                    return const Divider();
                  },
                )
            ),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child:Row(children:[
                TextButton(onPressed: () {
                  setState(() {
                    _recent = true;
                  });
                }, child: const Text("Recent"),),
                TextButton(onPressed: () {
                  setState(() {
                    _recent = false;
                    _runwayLength = 0;
                  });
                }, child: const Text("Nearest"),),
                TextButton(onPressed: () {
                  setState(() {
                    _runwayLength = 2000;
                    _recent = false;
                  });
                }, child: const Text("Nearest 2K"),),
                TextButton(onPressed: () {
                  setState(() {
                    _runwayLength = 4000;
                    _recent = false;
                  });
                }, child: const Text("Nearest 4K"),),
              ]
            )))
          ]),
        ]
      )
    );
  }
}

