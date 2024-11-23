package com.pakelcomedy.qleon.ui.home

import androidx.fragment.app.Fragment
import androidx.viewpager2.adapter.FragmentStateAdapter
import com.pakelcomedy.qleon.ui.homechat.HomeChatFragment
import com.pakelcomedy.qleon.ui.newchat.NewChatFragment

class HomeViewPagerAdapter(fragment: Fragment) : FragmentStateAdapter(fragment) {

    override fun getItemCount(): Int = 2 // Two tabs: Home Chat and New Chat

    override fun createFragment(position: Int): Fragment {
        return when (position) {
            0 -> HomeChatFragment() // Placeholder fragment for Home Chat
            1 -> NewChatFragment() // New Chat
            else -> throw IllegalStateException("Invalid position: $position")
        }
    }
}
