import 'package:flutter/material.dart';

class HomeProvider extends ChangeNotifier{
  int currentIndex = 0;
  void onTap(int index){
    currentIndex = index;
    notifyListeners();
  }
}